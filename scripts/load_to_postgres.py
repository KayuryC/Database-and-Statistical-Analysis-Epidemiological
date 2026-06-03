#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import os
import sys
from pathlib import Path

from sinan_utils import CSV_COLUMNS, RAW_COLUMNS, clean_raw_value, row_hash_from_csv_row


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CSV = PROJECT_ROOT / "data" / "raw" / "ZIKA_BR_2018_2026_UNIFICADO.csv"
SQL_FILES = [
    PROJECT_ROOT / "sql" / "00_create_schemas.sql",
    PROJECT_ROOT / "sql" / "01_create_tables.sql",
    PROJECT_ROOT / "sql" / "02_seed_dimensions.sql",
]
TRANSFORM_SQL = PROJECT_ROOT / "sql" / "03_transform_core_from_staging.sql"
STAGING_TABLE = "staging.notificacoes_zika_raw"
CORE_TABLE = "core.notificacao_zika"
DEFAULT_BATCH_SIZE = 5_000


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Carrega o CSV de Zika/SINAN no PostgreSQL local."
    )
    parser.add_argument(
        "--database-url",
        default=os.environ.get("DATABASE_URL"),
        help="URL PostgreSQL. Ex.: postgresql://usuario:senha@localhost:5432/zika_sinan",
    )
    parser.add_argument(
        "--csv",
        type=Path,
        default=DEFAULT_CSV,
        help=f"Caminho do CSV bruto. Padrão: {DEFAULT_CSV}",
    )
    parser.add_argument(
        "--mode",
        choices=("reload", "append"),
        default="reload",
        help="reload limpa staging/core antes da carga; append preserva dados existentes.",
    )
    parser.add_argument(
        "--batch-size",
        type=int,
        default=DEFAULT_BATCH_SIZE,
        help=f"Quantidade de linhas por lote de insert. Padrão: {DEFAULT_BATCH_SIZE}",
    )
    parser.add_argument(
        "--skip-schema",
        action="store_true",
        help="Não executa scripts de criação de schemas/tabelas/dimensões.",
    )
    return parser.parse_args()


def import_database_driver():
    try:
        import psycopg

        return psycopg
    except ImportError:
        try:
            import psycopg2

            return psycopg2
        except ImportError as exc:
            raise RuntimeError(
                "Driver PostgreSQL não encontrado. Instale com: "
                "python3 -m pip install 'psycopg[binary]'"
            ) from exc


def connect(database_url: str):
    driver = import_database_driver()
    return driver.connect(database_url)


def execute_sql_file(connection, path: Path) -> int:
    sql = path.read_text(encoding="utf-8")
    with connection.cursor() as cursor:
        cursor.execute(sql)
        rowcount = cursor.rowcount if cursor.rowcount is not None else -1
    connection.commit()
    return rowcount


def prepare_schema(connection) -> None:
    for sql_file in SQL_FILES:
        execute_sql_file(connection, sql_file)


def reset_tables(connection) -> None:
    with connection.cursor() as cursor:
        cursor.execute(
            f"TRUNCATE TABLE {CORE_TABLE}, {STAGING_TABLE} RESTART IDENTITY CASCADE;"
        )
    connection.commit()


def validate_csv_header(csv_path: Path) -> None:
    with csv_path.open("r", encoding="utf-8-sig", newline="") as csv_file:
        reader = csv.DictReader(csv_file)
        fieldnames = reader.fieldnames or []

    missing = [column for column in CSV_COLUMNS if column not in fieldnames]
    extra = [column for column in fieldnames if column not in CSV_COLUMNS]

    if missing:
        raise ValueError(f"Colunas ausentes no CSV: {', '.join(missing)}")
    if extra:
        print(f"Aviso: colunas extras ignoradas: {', '.join(extra)}", file=sys.stderr)


def staging_insert_sql() -> str:
    insert_columns = RAW_COLUMNS + ["row_hash", "is_duplicate"]
    placeholders = ", ".join(["%s"] * len(insert_columns))
    columns_sql = ", ".join(insert_columns)
    return f"INSERT INTO {STAGING_TABLE} ({columns_sql}) VALUES ({placeholders})"


def flush_batch(connection, insert_sql: str, batch: list[tuple[object, ...]]) -> None:
    if not batch:
        return
    with connection.cursor() as cursor:
        cursor.executemany(insert_sql, batch)
    connection.commit()


def iter_staging_rows(csv_path: Path):
    seen_hashes: set[str] = set()
    with csv_path.open("r", encoding="utf-8-sig", newline="") as csv_file:
        reader = csv.DictReader(csv_file)
        for row in reader:
            raw_values = [clean_raw_value(row.get(column)) for column in CSV_COLUMNS]
            row_hash = row_hash_from_csv_row(row)
            is_duplicate = row_hash in seen_hashes
            seen_hashes.add(row_hash)
            yield tuple(raw_values + [row_hash, is_duplicate]), is_duplicate


def load_staging(connection, csv_path: Path, batch_size: int) -> tuple[int, int]:
    insert_sql = staging_insert_sql()
    batch: list[tuple[object, ...]] = []
    total_rows = 0
    duplicate_rows = 0

    for values, is_duplicate in iter_staging_rows(csv_path):
        batch.append(values)
        total_rows += 1
        duplicate_rows += int(is_duplicate)

        if len(batch) >= batch_size:
            flush_batch(connection, insert_sql, batch)
            batch.clear()
            print(f"Staging: {total_rows} linhas carregadas...")

    flush_batch(connection, insert_sql, batch)
    return total_rows, duplicate_rows


def transform_core(connection) -> int:
    return execute_sql_file(connection, TRANSFORM_SQL)


def start_load_log(connection, source_file: Path, mode: str) -> int:
    with connection.cursor() as cursor:
        cursor.execute(
            """
            INSERT INTO core.etl_load_log (source_file, mode)
            VALUES (%s, %s)
            RETURNING load_id;
            """,
            (str(source_file), mode),
        )
        load_id = cursor.fetchone()[0]
    connection.commit()
    return load_id


def finish_load_log(
    connection,
    load_id: int,
    status: str,
    rows_loaded: int,
    rows_inserted_core: int,
    notes: str,
) -> None:
    with connection.cursor() as cursor:
        cursor.execute(
            """
            UPDATE core.etl_load_log
            SET finished_at = CURRENT_TIMESTAMP,
                rows_loaded = %s,
                rows_inserted_core = %s,
                status = %s,
                notes = %s
            WHERE load_id = %s;
            """,
            (rows_loaded, rows_inserted_core, status, notes, load_id),
        )
    connection.commit()


def run() -> None:
    args = parse_args()
    if not args.database_url:
        raise ValueError("Informe --database-url ou defina a variável DATABASE_URL.")
    if not args.csv.exists():
        raise FileNotFoundError(f"CSV não encontrado: {args.csv}")
    if args.batch_size <= 0:
        raise ValueError("--batch-size deve ser maior que zero.")

    validate_csv_header(args.csv)

    connection = connect(args.database_url)
    load_id = None
    rows_loaded = 0
    rows_inserted_core = 0
    duplicate_rows = 0

    try:
        if not args.skip_schema:
            prepare_schema(connection)
        if args.mode == "reload":
            reset_tables(connection)

        load_id = start_load_log(connection, args.csv, args.mode)
        rows_loaded, duplicate_rows = load_staging(connection, args.csv, args.batch_size)
        rows_inserted_core = transform_core(connection)
        finish_load_log(
            connection,
            load_id,
            "success",
            rows_loaded,
            rows_inserted_core,
            f"{duplicate_rows} duplicatas completas marcadas por row_hash.",
        )

        print("Carga concluída.")
        print(f"Staging: {rows_loaded} linhas.")
        print(f"Core: {rows_inserted_core} linhas inseridas.")
        print(f"Duplicatas completas marcadas: {duplicate_rows}.")
    except Exception:
        connection.rollback()
        if load_id is not None:
            finish_load_log(
                connection,
                load_id,
                "failed",
                rows_loaded,
                rows_inserted_core,
                f"{duplicate_rows} duplicatas marcadas antes da falha.",
            )
        raise
    finally:
        connection.close()


if __name__ == "__main__":
    run()
