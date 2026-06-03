# Guia de Execução Local

Este guia reproduz o projeto em um PostgreSQL local 15+.

## 1. Preparar Python

```bash
python3 -m pip install -r requirements.txt
```

## 2. Preparar PostgreSQL

Criar o banco local:

```bash
createdb zika_sinan
export DATABASE_URL="postgresql://usuario:senha@localhost:5432/zika_sinan"
```

Se o PostgreSQL local usa autenticação sem senha, ajuste a URL conforme seu ambiente.

## 3. Gerar diagnóstico do CSV

```bash
python3 scripts/profile_csv.py
```

Saída esperada:

```text
docs/reports/perfil_csv_zika.md
```

## 4. Carregar banco

```bash
python3 scripts/load_to_postgres.py \
  --database-url "$DATABASE_URL" \
  --csv data/raw/ZIKA_BR_2018_2026_UNIFICADO.csv \
  --mode reload
```

Resultado esperado:

- 236.398 linhas em `staging.notificacoes_zika_raw`.
- Linhas transformadas em `core.notificacao_zika`.
- 288 duplicatas completas marcadas por `row_hash`.

## 5. Aplicar funções, triggers e views

Após a carga histórica:

```bash
psql "$DATABASE_URL" -f sql/04_functions_triggers.sql
psql "$DATABASE_URL" -f sql/05_dashboard_views.sql
```

O ETL já executa `00_create_schemas.sql`, `01_create_tables.sql`, `02_seed_dimensions.sql` e `03_transform_core_from_staging.sql`.

## 6. Testar SQL

```bash
psql "$DATABASE_URL" -f sql/98_smoke_tests.sql
```

O teste roda dentro de transação e termina com `ROLLBACK`.

## 7. Gerar análise estatística

Preferencialmente usando o banco:

```bash
python3 scripts/run_statistical_analysis.py \
  --database-url "$DATABASE_URL" \
  --output docs/reports/analise_estatistica.md
```

Fallback por CSV:

```bash
python3 scripts/run_statistical_analysis.py --source csv
```

## Observações

- `CLASSI_FIN = 1` define os casos confirmados.
- `DT_SIN_PRI`/`SEM_PRI` são preferenciais para curva epidêmica.
- O CSV bruto permanece ignorado pelo Git em `data/raw/`.
- Se `prophet` não estiver instalado, o relatório usa fallback linear e explicita isso.
