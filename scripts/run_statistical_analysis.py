#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
import sys
import warnings
from datetime import datetime, timezone
from pathlib import Path

os.environ.setdefault("LOKY_MAX_CPU_COUNT", "1")
warnings.filterwarnings("ignore", message="Could not find the number of physical cores.*")
warnings.filterwarnings("ignore", category=RuntimeWarning, module="sklearn.utils.extmath")

import numpy as np
import pandas as pd
from sklearn.cluster import KMeans
from sklearn.preprocessing import StandardScaler

from sinan_utils import decode_idade_sinan


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CSV = PROJECT_ROOT / "data" / "raw" / "ZIKA_BR_2018_2026_UNIFICADO.csv"
DEFAULT_OUTPUT = PROJECT_ROOT / "docs" / "reports" / "analise_estatistica.md"
MIN_CASES_FOR_CLUSTER = 20
FORECAST_WEEKS = 12


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Gera análise estatística epidemiológica da base Zika/SINAN."
    )
    parser.add_argument(
        "--database-url",
        default=os.environ.get("DATABASE_URL"),
        help="URL PostgreSQL. Se omitida, o script usa o CSV bruto como fallback.",
    )
    parser.add_argument(
        "--csv",
        type=Path,
        default=DEFAULT_CSV,
        help=f"CSV bruto usado no fallback. Padrão: {DEFAULT_CSV}",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=DEFAULT_OUTPUT,
        help=f"Relatório Markdown de saída. Padrão: {DEFAULT_OUTPUT}",
    )
    parser.add_argument(
        "--source",
        choices=("auto", "database", "csv"),
        default="auto",
        help="Fonte de dados. auto tenta PostgreSQL e cai para CSV se necessário.",
    )
    return parser.parse_args()


def load_from_database(database_url: str) -> pd.DataFrame:
    from load_to_postgres import connect

    query = """
        SELECT
            nu_ano,
            sem_pri,
            uf_residencia,
            municipio_residencia,
            classi_fin_codigo,
            idade_anos,
            sexo_codigo,
            gestante_codigo,
            evolucao_codigo
        FROM core.notificacao_zika;
    """
    connection = connect(database_url)
    try:
        return pd.read_sql_query(query, connection)
    finally:
        connection.close()


def load_from_csv(csv_path: Path) -> pd.DataFrame:
    usecols = [
        "NU_ANO",
        "SEM_PRI",
        "SG_UF",
        "ID_MN_RESI",
        "CLASSI_FIN",
        "NU_IDADE_N",
        "CS_SEXO",
        "CS_GESTANT",
        "EVOLUCAO",
    ]
    raw = pd.read_csv(csv_path, usecols=usecols, dtype=str, encoding="utf-8-sig")
    data = pd.DataFrame(
        {
            "nu_ano": to_numeric(raw["NU_ANO"]),
            "sem_pri": to_numeric(raw["SEM_PRI"]),
            "uf_residencia": to_numeric(raw["SG_UF"]),
            "municipio_residencia": to_numeric(raw["ID_MN_RESI"]),
            "classi_fin_codigo": to_numeric(raw["CLASSI_FIN"]),
            "idade_anos": raw["NU_IDADE_N"].map(decode_idade_sinan),
            "sexo_codigo": raw["CS_SEXO"].str.strip().str.upper(),
            "gestante_codigo": to_numeric(raw["CS_GESTANT"]),
            "evolucao_codigo": to_numeric(raw["EVOLUCAO"]),
        }
    )
    return data


def load_data(args: argparse.Namespace) -> tuple[pd.DataFrame, str, str]:
    if args.source in ("auto", "database") and args.database_url:
        try:
            data = load_from_database(args.database_url)
            return data, "PostgreSQL", "Dados carregados de core.notificacao_zika."
        except Exception as exc:
            if args.source == "database":
                raise
            print(f"Aviso: usando CSV por falha no banco: {exc}", file=sys.stderr)

    if args.source == "database":
        raise ValueError("Fonte database exige --database-url ou DATABASE_URL.")
    if not args.csv.exists():
        raise FileNotFoundError(f"CSV não encontrado: {args.csv}")

    data = load_from_csv(args.csv)
    return data, "CSV", f"Fallback local usando {relative_path(args.csv)}."


def to_numeric(series: pd.Series) -> pd.Series:
    return pd.to_numeric(series.str.strip(), errors="coerce")


def relative_path(path: Path) -> str:
    resolved_path = path.resolve()
    try:
        return resolved_path.relative_to(PROJECT_ROOT).as_posix()
    except ValueError:
        return resolved_path.as_posix()


def format_int(value: object) -> str:
    if pd.isna(value):
        return "-"
    return f"{int(round(float(value))):,}".replace(",", ".")


def format_float(value: object, digits: int = 2) -> str:
    if pd.isna(value):
        return "-"
    return f"{float(value):.{digits}f}"


def confirmed_cases(data: pd.DataFrame) -> pd.DataFrame:
    return data[data["classi_fin_codigo"] == 1].copy()


def analyze_seasonality(confirmed: pd.DataFrame) -> pd.DataFrame:
    weekly = confirmed.dropna(subset=["sem_pri"]).copy()
    weekly["semana_epidemiologica"] = (weekly["sem_pri"].astype(int) % 100).astype(int)
    return (
        weekly.groupby("semana_epidemiologica")
        .size()
        .reset_index(name="casos_confirmados")
        .sort_values("casos_confirmados", ascending=False)
    )


def analyze_trends(confirmed: pd.DataFrame) -> pd.DataFrame:
    yearly = (
        confirmed.dropna(subset=["uf_residencia", "nu_ano"])
        .groupby(["uf_residencia", "nu_ano"])
        .size()
        .reset_index(name="casos_confirmados")
    )
    rows = []
    for uf_code, group in yearly.groupby("uf_residencia"):
        if group["nu_ano"].nunique() < 3:
            continue
        ordered = group.sort_values("nu_ano")
        years = ordered["nu_ano"].to_numpy(dtype=float)
        cases = ordered["casos_confirmados"].to_numpy(dtype=float)
        slope, intercept = np.polyfit(years, cases, deg=1)
        predicted = slope * years + intercept
        residual = cases - predicted
        total_variance = np.sum((cases - cases.mean()) ** 2)
        r_squared = 1 - np.sum(residual**2) / total_variance if total_variance else np.nan
        rows.append(
            {
                "uf_residencia": int(uf_code),
                "anos_observados": int(len(ordered)),
                "casos_ultimo_ano": int(cases[-1]),
                "tendencia_casos_por_ano": float(slope),
                "r2": float(r_squared) if not np.isnan(r_squared) else np.nan,
            }
        )
    return pd.DataFrame(rows).sort_values("tendencia_casos_por_ano", ascending=False)


def epidemiological_week_to_date(year_week: int) -> pd.Timestamp | pd.NaT:
    try:
        year = int(year_week) // 100
        week = int(year_week) % 100
        if week < 1 or week > 53:
            return pd.NaT
        return pd.Timestamp(datetime.fromisocalendar(year, week, 1).date())
    except ValueError:
        return pd.NaT


def forecast_cases(confirmed: pd.DataFrame) -> tuple[str, pd.DataFrame]:
    weekly = (
        confirmed.dropna(subset=["sem_pri"])
        .groupby("sem_pri")
        .size()
        .reset_index(name="y")
        .sort_values("sem_pri")
    )
    weekly["ds"] = weekly["sem_pri"].astype(int).map(epidemiological_week_to_date)
    weekly = weekly.dropna(subset=["ds"])
    weekly = weekly[["ds", "y"]]

    try:
        from prophet import Prophet

        model = Prophet(yearly_seasonality=True, weekly_seasonality=False, daily_seasonality=False)
        model.fit(weekly)
        future = model.make_future_dataframe(periods=FORECAST_WEEKS, freq="W-MON")
        forecast = model.predict(future).tail(FORECAST_WEEKS)
        output = forecast[["ds", "yhat", "yhat_lower", "yhat_upper"]].copy()
        output["yhat"] = output["yhat"].clip(lower=0)
        output["yhat_lower"] = output["yhat_lower"].clip(lower=0)
        output["yhat_upper"] = output["yhat_upper"].clip(lower=0)
        return "Prophet", output
    except Exception as exc:
        if len(weekly) < 2:
            return f"Fallback linear indisponível ({exc})", pd.DataFrame()

        positions = np.arange(len(weekly), dtype=float)
        slope, intercept = np.polyfit(positions, weekly["y"].to_numpy(dtype=float), deg=1)
        future_positions = np.arange(len(weekly), len(weekly) + FORECAST_WEEKS, dtype=float)
        last_date = weekly["ds"].max()
        future_dates = pd.date_range(last_date + pd.Timedelta(weeks=1), periods=FORECAST_WEEKS, freq="W-MON")
        predictions = np.maximum(0, slope * future_positions + intercept)
        forecast = pd.DataFrame(
            {
                "ds": future_dates,
                "yhat": predictions,
                "yhat_lower": np.maximum(0, predictions * 0.85),
                "yhat_upper": predictions * 1.15,
            }
        )
        return f"Fallback linear sem Prophet ({exc})", forecast


def cluster_municipalities(confirmed: pd.DataFrame) -> pd.DataFrame:
    municipality = confirmed.dropna(subset=["municipio_residencia"]).copy()
    municipality["is_female"] = municipality["sexo_codigo"].eq("F")
    municipality["is_gestante"] = municipality["gestante_codigo"].isin([1, 2, 3, 4])
    municipality["is_obito"] = municipality["evolucao_codigo"].isin([2, 3])

    features = (
        municipality.groupby("municipio_residencia")
        .agg(
            total_casos=("classi_fin_codigo", "size"),
            idade_media=("idade_anos", "mean"),
            pct_feminino=("is_female", "mean"),
            pct_gestante=("is_gestante", "mean"),
            pct_obito=("is_obito", "mean"),
        )
        .reset_index()
    )
    features = features[features["total_casos"] >= MIN_CASES_FOR_CLUSTER].copy()
    features["idade_media"] = features["idade_media"].fillna(features["idade_media"].median())

    if len(features) < 2:
        return pd.DataFrame()

    feature_columns = ["total_casos", "idade_media", "pct_feminino", "pct_gestante", "pct_obito"]
    scaled = StandardScaler().fit_transform(features[feature_columns])
    cluster_count = min(4, len(features))
    model = KMeans(n_clusters=cluster_count, random_state=42, n_init=10)
    features["cluster"] = model.fit_predict(scaled)

    return (
        features.groupby("cluster")
        .agg(
            municipios=("municipio_residencia", "count"),
            total_casos_soma=("total_casos", "sum"),
            total_casos_mediana=("total_casos", "median"),
            idade_media=("idade_media", "mean"),
            pct_feminino=("pct_feminino", "mean"),
            pct_gestante=("pct_gestante", "mean"),
            pct_obito=("pct_obito", "mean"),
        )
        .reset_index()
        .sort_values("total_casos_soma", ascending=False)
    )


def markdown_table(data: pd.DataFrame, columns: list[str], limit: int | None = None) -> list[str]:
    table = data[columns].head(limit) if limit else data[columns]
    lines = ["| " + " | ".join(columns) + " |", "| " + " | ".join(["---"] * len(columns)) + " |"]
    for _, row in table.iterrows():
        values = []
        for column in columns:
            value = row[column]
            if isinstance(value, (np.integer, int)):
                values.append(format_int(value))
            elif isinstance(value, (np.floating, float)):
                if np.isfinite(value) and float(value).is_integer():
                    values.append(format_int(value))
                else:
                    values.append(format_float(value))
            elif isinstance(value, pd.Timestamp):
                values.append(value.date().isoformat())
            else:
                values.append(str(value))
        lines.append("| " + " | ".join(values) + " |")
    return lines


def build_report(data: pd.DataFrame, source_name: str, source_note: str) -> str:
    confirmed = confirmed_cases(data)
    seasonality = analyze_seasonality(confirmed)
    trends = analyze_trends(confirmed)
    forecast_method, forecast = forecast_cases(confirmed)
    clusters = cluster_municipalities(confirmed)
    generated_at = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")

    lines = [
        "# Análise estatística epidemiológica — Zika/SINAN",
        "",
        f"Gerado em: `{generated_at}`",
        f"Fonte usada: `{source_name}` — {source_note}",
        "",
        "## Resumo da base analisada",
        "",
        "| Métrica | Valor |",
        "|---|---:|",
        f"| Notificações analisadas | {format_int(len(data))} |",
        f"| Casos confirmados (`CLASSI_FIN = 1`) | {format_int(len(confirmed))} |",
        f"| UFs com casos confirmados | {format_int(confirmed['uf_residencia'].nunique())} |",
        f"| Municípios com casos confirmados | {format_int(confirmed['municipio_residencia'].nunique())} |",
        "",
        "## Sazonalidade",
        "",
        "Semanas epidemiológicas com maior volume de casos confirmados:",
        "",
        *markdown_table(seasonality, ["semana_epidemiologica", "casos_confirmados"], limit=10),
        "",
        "## Tendência por UF",
        "",
        "Maiores tendências lineares positivas em casos confirmados por ano:",
        "",
    ]

    if trends.empty:
        lines.append("- Dados insuficientes para tendência por UF.")
    else:
        lines.extend(
            markdown_table(
                trends,
                ["uf_residencia", "anos_observados", "casos_ultimo_ano", "tendencia_casos_por_ano", "r2"],
                limit=10,
            )
        )
        lines.extend(
            [
                "",
                "Maiores tendências lineares negativas em casos confirmados por ano:",
                "",
                *markdown_table(
                    trends.sort_values("tendencia_casos_por_ano"),
                    ["uf_residencia", "anos_observados", "casos_ultimo_ano", "tendencia_casos_por_ano", "r2"],
                    limit=10,
                ),
            ]
        )

    lines.extend(
        [
            "",
            "## Previsão de casos",
            "",
            f"Método usado: `{forecast_method}`.",
            "",
        ]
    )
    if forecast.empty:
        lines.append("- Dados insuficientes para previsão.")
    else:
        lines.extend(markdown_table(forecast, ["ds", "yhat", "yhat_lower", "yhat_upper"], limit=FORECAST_WEEKS))

    lines.extend(
        [
            "",
            "## Agrupamento municipal por perfil epidemiológico",
            "",
            f"Critério: municípios com pelo menos {MIN_CASES_FOR_CLUSTER} casos confirmados.",
            "",
        ]
    )
    if clusters.empty:
        lines.append("- Dados insuficientes para K-Means municipal.")
    else:
        lines.extend(
            markdown_table(
                clusters,
                [
                    "cluster",
                    "municipios",
                    "total_casos_soma",
                    "total_casos_mediana",
                    "idade_media",
                    "pct_feminino",
                    "pct_gestante",
                    "pct_obito",
                ],
            )
        )

    lines.extend(
        [
            "",
            "## Notas metodológicas",
            "",
            "- As análises usam apenas casos confirmados para tendência, previsão, sazonalidade e clusterização.",
            "- Semanas epidemiológicas são convertidas para segundas-feiras ISO apenas para previsão temporal.",
            "- Se `prophet` não estiver instalado, a previsão usa fallback linear e informa isso no relatório.",
            "- K-Means usa variáveis padronizadas: volume, idade média, proporção feminina, gestantes e óbitos.",
        ]
    )

    return "\n".join(lines) + "\n"


def main() -> None:
    args = parse_args()
    data, source_name, source_note = load_data(args)
    report = build_report(data, source_name, source_note)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(report, encoding="utf-8")
    print(f"Relatório gerado em: {args.output}")


if __name__ == "__main__":
    main()
