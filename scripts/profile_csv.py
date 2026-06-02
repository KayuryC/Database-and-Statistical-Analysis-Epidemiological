#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import hashlib
from collections import Counter
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_INPUT = PROJECT_ROOT / "data" / "raw" / "ZIKA_BR_2018_2026_UNIFICADO.csv"
DEFAULT_OUTPUT = PROJECT_ROOT / "docs" / "reports" / "perfil_csv_zika.md"
DATE_FORMAT = "%Y-%m-%d"
NULL_VALUES = {"", "NA", "N/A", "NULL", "NONE", "NAN"}


@dataclass
class DateStats:
    minimum: str | None = None
    maximum: str | None = None
    invalid: int = 0


@dataclass
class ColumnStats:
    name: str
    blanks: int = 0
    values: Counter[str] = field(default_factory=Counter)
    dates: DateStats = field(default_factory=DateStats)

    @property
    def non_blank(self) -> int:
        return sum(self.values.values())

    @property
    def distinct(self) -> int:
        return len(self.values)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Gera um perfil inicial do CSV unificado de Zika/SINAN."
    )
    parser.add_argument(
        "--input",
        type=Path,
        default=DEFAULT_INPUT,
        help=f"Caminho do CSV bruto. Padrão: {DEFAULT_INPUT}",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=DEFAULT_OUTPUT,
        help=f"Caminho do relatório Markdown. Padrão: {DEFAULT_OUTPUT}",
    )
    parser.add_argument(
        "--top-values",
        type=int,
        default=5,
        help="Quantidade de valores frequentes exibidos por coluna.",
    )
    return parser.parse_args()


def is_blank(value: str | None) -> bool:
    return value is None or value.strip().upper() in NULL_VALUES


def detect_encoding(path: Path) -> str:
    sample = path.read_bytes()[:8192]
    for encoding in ("utf-8-sig", "utf-8", "latin1"):
        try:
            sample.decode(encoding)
            return encoding
        except UnicodeDecodeError:
            continue
    return "utf-8-sig"


def detect_dialect(path: Path, encoding: str) -> csv.Dialect:
    with path.open("r", encoding=encoding, newline="") as csv_file:
        sample = csv_file.read(8192)
    try:
        return csv.Sniffer().sniff(sample, delimiters=",;\t|")
    except csv.Error:
        return csv.get_dialect("excel")


def parse_date(value: str) -> str | None:
    try:
        return datetime.strptime(value, DATE_FORMAT).date().isoformat()
    except ValueError:
        return None


def update_date_stats(stats: DateStats, value: str) -> None:
    parsed = parse_date(value)
    if parsed is None:
        stats.invalid += 1
        return

    if stats.minimum is None or parsed < stats.minimum:
        stats.minimum = parsed
    if stats.maximum is None or parsed > stats.maximum:
        stats.maximum = parsed


def markdown_escape(value: object) -> str:
    text = str(value)
    return text.replace("\\", "\\\\").replace("|", "\\|").replace("\n", " ")


def short_value(value: str, max_length: int = 35) -> str:
    clean = value.strip()
    if len(clean) <= max_length:
        return clean
    return f"{clean[: max_length - 1]}…"


def display_path(path: Path) -> str:
    resolved_path = path.resolve()
    try:
        return resolved_path.relative_to(PROJECT_ROOT).as_posix()
    except ValueError:
        return resolved_path.as_posix()


def pct(part: int, total: int) -> str:
    if total == 0:
        return "0.0%"
    return f"{part / total * 100:.1f}%"


def format_int(value: int) -> str:
    return f"{value:,}".replace(",", ".")


def row_digest(row: dict[str, str], columns: list[str]) -> bytes:
    content = "\x1f".join(row.get(column, "") or "" for column in columns)
    return hashlib.sha1(content.encode("utf-8")).digest()


def profile_csv(path: Path) -> dict[str, object]:
    if not path.exists():
        raise FileNotFoundError(f"CSV não encontrado: {path}")

    encoding = detect_encoding(path)
    dialect = detect_dialect(path, encoding)

    with path.open("r", encoding=encoding, newline="") as csv_file:
        reader = csv.DictReader(csv_file, dialect=dialect)
        if reader.fieldnames is None:
            raise ValueError("CSV sem cabeçalho.")

        columns = list(reader.fieldnames)
        column_stats = {column: ColumnStats(column) for column in columns}
        years = Counter()
        seen_rows: set[bytes] = set()
        duplicated_rows = 0
        malformed_rows = 0
        total_rows = 0

        for row in reader:
            total_rows += 1

            if row.get(None) is not None or any(row.get(column) is None for column in columns):
                malformed_rows += 1

            year = row.get("ano_arquivo") or row.get("NU_ANO") or ""
            if not is_blank(year):
                years[year.strip()] += 1

            digest = row_digest(row, columns)
            if digest in seen_rows:
                duplicated_rows += 1
            else:
                seen_rows.add(digest)

            for column in columns:
                value = row.get(column)
                stats = column_stats[column]
                if is_blank(value):
                    stats.blanks += 1
                    continue

                clean_value = value.strip()
                stats.values[clean_value] += 1

                if column.startswith("DT_"):
                    update_date_stats(stats.dates, clean_value)

    return {
        "path": path,
        "size_mb": path.stat().st_size / 1024 / 1024,
        "encoding": encoding,
        "delimiter": dialect.delimiter,
        "columns": columns,
        "column_stats": column_stats,
        "years": years,
        "total_rows": total_rows,
        "duplicated_rows": duplicated_rows,
        "malformed_rows": malformed_rows,
    }


def top_values(stats: ColumnStats, limit: int) -> str:
    if not stats.values:
        return "-"
    values = []
    for value, count in stats.values.most_common(limit):
        values.append(f"{markdown_escape(short_value(value))} ({count})")
    return ", ".join(values)


def build_report(profile: dict[str, object], top_values_limit: int) -> str:
    columns = profile["columns"]
    column_stats = profile["column_stats"]
    years = profile["years"]
    total_rows = int(profile["total_rows"])
    generated_at = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")

    lines = [
        "# Perfil inicial da base Zika/SINAN",
        "",
        f"Gerado em: `{generated_at}`",
        "",
        "## Resumo",
        "",
        "| Métrica | Valor |",
        "|---|---:|",
        f"| Arquivo | `{markdown_escape(display_path(Path(profile['path'])))}` |",
        f"| Tamanho | {float(profile['size_mb']):.2f} MB |",
        f"| Codificação | `{profile['encoding']}` |",
        f"| Delimitador | `{markdown_escape(profile['delimiter'])}` |",
        f"| Registros | {format_int(total_rows)} |",
        f"| Colunas | {len(columns)} |",
        f"| Linhas duplicadas completas | {format_int(int(profile['duplicated_rows']))} |",
        f"| Linhas malformadas | {format_int(int(profile['malformed_rows']))} |",
        "",
        "## Distribuição por ano",
        "",
        "| Ano | Registros |",
        "|---|---:|",
    ]

    for year, count in sorted(years.items()):
        lines.append(f"| {markdown_escape(year)} | {format_int(count)} |")

    emptiest_columns = sorted(
        column_stats.values(),
        key=lambda stats: (stats.blanks / total_rows if total_rows else 0),
        reverse=True,
    )

    lines.extend(
        [
            "",
            "## Colunas com mais vazios",
            "",
            "| Coluna | Vazios | % vazios |",
            "|---|---:|---:|",
        ]
    )

    for stats in emptiest_columns[:15]:
        lines.append(
            f"| `{markdown_escape(stats.name)}` | {format_int(stats.blanks)} | {pct(stats.blanks, total_rows)} |"
        )

    date_columns = [
        stats
        for stats in column_stats.values()
        if stats.name.startswith("DT_")
    ]

    lines.extend(
        [
            "",
            "## Qualidade dos campos de data",
            "",
            "| Coluna | Menor data | Maior data | Datas inválidas |",
            "|---|---:|---:|---:|",
        ]
    )

    for stats in date_columns:
        lines.append(
            "| "
            f"`{markdown_escape(stats.name)}` | "
            f"{stats.dates.minimum or '-'} | "
            f"{stats.dates.maximum or '-'} | "
            f"{format_int(stats.dates.invalid)} |"
        )

    lines.extend(
        [
            "",
            "## Perfil por coluna",
            "",
            "| Coluna | Vazios | % vazios | Distintos não vazios | Valores mais frequentes |",
            "|---|---:|---:|---:|---|",
        ]
    )

    for column in columns:
        stats = column_stats[column]
        lines.append(
            f"| `{markdown_escape(column)}` | "
            f"{format_int(stats.blanks)} | "
            f"{pct(stats.blanks, total_rows)} | "
            f"{format_int(stats.distinct)} | "
            f"{top_values(stats, top_values_limit)} |"
        )

    fully_blank = [stats.name for stats in column_stats.values() if stats.blanks == total_rows]
    high_blank = [
        stats.name
        for stats in column_stats.values()
        if total_rows and stats.blanks / total_rows >= 0.75 and stats.blanks != total_rows
    ]

    lines.extend(["", "## Observações automáticas", ""])
    if fully_blank:
        lines.append(
            "- Colunas totalmente vazias: "
            + ", ".join(f"`{markdown_escape(column)}`" for column in fully_blank)
            + "."
        )
    if high_blank:
        lines.append(
            "- Colunas com pelo menos 75% de vazios: "
            + ", ".join(f"`{markdown_escape(column)}`" for column in high_blank)
            + "."
        )
    if int(profile["duplicated_rows"]) == 0:
        lines.append("- Não foram encontradas linhas completamente duplicadas.")
    if int(profile["malformed_rows"]) == 0:
        lines.append("- Não foram encontradas linhas com quantidade irregular de campos.")

    return "\n".join(lines) + "\n"


def main() -> None:
    args = parse_args()
    profile = profile_csv(args.input)
    report = build_report(profile, args.top_values)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(report, encoding="utf-8")
    print(f"Relatório gerado em: {args.output}")


if __name__ == "__main__":
    main()
