# Análise estatística epidemiológica — Zika/SINAN

Gerado em: `2026-06-03 19:24:54 UTC`
Fonte usada: `CSV` — Fallback local usando data/raw/ZIKA_BR_2018_2026_UNIFICADO.csv.

## Resumo da base analisada

| Métrica | Valor |
|---|---:|
| Notificações analisadas | 236.398 |
| Casos confirmados (`CLASSI_FIN = 1`) | 28.328 |
| UFs com casos confirmados | 27 |
| Municípios com casos confirmados | 1.735 |

## Sazonalidade

Semanas epidemiológicas com maior volume de casos confirmados:

| semana_epidemiologica | casos_confirmados |
| --- | --- |
| 20 | 1.057 |
| 19 | 975 |
| 18 | 970 |
| 12 | 933 |
| 14 | 931 |
| 17 | 927 |
| 10 | 899 |
| 13 | 896 |
| 11 | 878 |
| 15 | 875 |

## Tendência por UF

Maiores tendências lineares positivas em casos confirmados por ano:

| uf_residencia | anos_observados | casos_ultimo_ano | tendencia_casos_por_ano | r2 |
| --- | --- | --- | --- | --- |
| 51 | 9 | 126 | 40.32 | 0.11 |
| 14 | 9 | 4 | 0.10 | 0.00 |
| 42 | 6 | 1 | 0.00 | 0.00 |
| 21 | 9 | 4 | -0.38 | 0.00 |
| 24 | 9 | 9 | -0.52 | 0.00 |
| 41 | 6 | 1 | -0.55 | 0.42 |
| 43 | 9 | 1 | -1.25 | 0.02 |
| 16 | 9 | 1 | -1.32 | 0.06 |
| 22 | 8 | 26 | -2.12 | 0.17 |
| 11 | 9 | 10 | -2.20 | 0.09 |

Maiores tendências lineares negativas em casos confirmados por ano:

| uf_residencia | anos_observados | casos_ultimo_ano | tendencia_casos_por_ano | r2 |
| --- | --- | --- | --- | --- |
| 33 | 7 | 1 | -237.29 | 0.70 |
| 25 | 8 | 9 | -48.50 | 0.06 |
| 32 | 8 | 2 | -37.47 | 0.08 |
| 27 | 9 | 15 | -35.72 | 0.21 |
| 29 | 9 | 30 | -29.07 | 0.07 |
| 52 | 9 | 4 | -26.67 | 0.30 |
| 31 | 9 | 8 | -19.73 | 0.47 |
| 13 | 9 | 2 | -19.40 | 0.23 |
| 35 | 9 | 1 | -13.67 | 0.60 |
| 23 | 8 | 2 | -11.67 | 0.16 |

## Previsão de casos

Método usado: `Fallback linear sem Prophet (No module named 'prophet')`.

| ds | yhat | yhat_lower | yhat_upper |
| --- | --- | --- | --- |
| 2026-04-13 | 48.55 | 41.27 | 55.84 |
| 2026-04-20 | 48.51 | 41.23 | 55.78 |
| 2026-04-27 | 48.46 | 41.19 | 55.73 |
| 2026-05-04 | 48.42 | 41.16 | 55.68 |
| 2026-05-11 | 48.37 | 41.12 | 55.63 |
| 2026-05-18 | 48.33 | 41.08 | 55.58 |
| 2026-05-25 | 48.28 | 41.04 | 55.52 |
| 2026-06-01 | 48.24 | 41.00 | 55.47 |
| 2026-06-08 | 48.19 | 40.96 | 55.42 |
| 2026-06-15 | 48.15 | 40.92 | 55.37 |
| 2026-06-22 | 48.10 | 40.89 | 55.32 |
| 2026-06-29 | 48.06 | 40.85 | 55.26 |

## Agrupamento municipal por perfil epidemiológico

Critério: municípios com pelo menos 20 casos confirmados.

| cluster | municipios | total_casos_soma | total_casos_mediana | idade_media | pct_feminino | pct_gestante | pct_obito |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 0 | 197 | 12.907 | 43 | 32.25 | 0.63 | 0.04 | 0.00 |
| 3 | 9 | 6.447 | 583 | 31.31 | 0.62 | 0.06 | 0.00 |
| 2 | 21 | 1.498 | 36 | 28.29 | 0.78 | 0.25 | 0 |
| 1 | 22 | 1.399 | 58 | 30.24 | 0.66 | 0.08 | 0.02 |

## Notas metodológicas

- As análises usam apenas casos confirmados para tendência, previsão, sazonalidade e clusterização.
- Semanas epidemiológicas são convertidas para segundas-feiras ISO apenas para previsão temporal.
- Se `prophet` não estiver instalado, a previsão usa fallback linear e informa isso no relatório.
- K-Means usa variáveis padronizadas: volume, idade média, proporção feminina, gestantes e óbitos.
