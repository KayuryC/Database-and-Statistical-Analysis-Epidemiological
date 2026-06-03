# Modelagem Relacional — Zika/SINAN

## Estratégia

O modelo separa preservação do dado bruto, normalização operacional e consultas analíticas.

- `staging.notificacoes_zika_raw`: recebe o CSV bruto com as 43 colunas em texto, além de `row_hash`, `is_duplicate` e `loaded_at`.
- `core.notificacao_zika`: tabela fato tipada, derivada do staging, com datas, códigos, idade decodificada e chaves para dimensões.
- `core.dim_*`: domínios estáveis usados para traduzir códigos categóricos.
- `audit.audit_log`: histórico de alterações em JSONB.
- `analytics.*`: funções e views para análise epidemiológica.

## Relações principais

```text
staging.notificacoes_zika_raw 1 ── 0..1 core.notificacao_zika

core.dim_uf                   1 ── N core.notificacao_zika
core.dim_sexo                 1 ── N core.notificacao_zika
core.dim_gestante             1 ── N core.notificacao_zika
core.dim_raca                 1 ── N core.notificacao_zika
core.dim_escolaridade         1 ── N core.notificacao_zika
core.dim_classificacao_final  1 ── N core.notificacao_zika
core.dim_criterio             1 ── N core.notificacao_zika
core.dim_autoctonia           1 ── N core.notificacao_zika
core.dim_doenca_trabalho      1 ── N core.notificacao_zika
core.dim_evolucao             1 ── N core.notificacao_zika
```

## Decisões de desenho

- O staging preserva valores como texto para evitar perda de informação na ingestão.
- A tabela fato guarda `raw_id` para rastrear cada registro tipado até a linha bruta.
- `row_hash` permite detectar linhas completamente duplicadas sem depender de identificador externo.
- `CLASSI_FIN = 1` define casos confirmados para views e análises epidemiológicas.
- Datas e códigos inválidos devem virar `NULL` na transformação, não zeros artificiais.
