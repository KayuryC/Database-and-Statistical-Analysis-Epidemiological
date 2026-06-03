# SQL

Scripts SQL do projeto, pensados para PostgreSQL 15+.

## Ordem de execução

```bash
psql "$DATABASE_URL" -f sql/00_create_schemas.sql
psql "$DATABASE_URL" -f sql/01_create_tables.sql
psql "$DATABASE_URL" -f sql/02_seed_dimensions.sql
psql "$DATABASE_URL" -f sql/03_transform_core_from_staging.sql
psql "$DATABASE_URL" -f sql/04_functions_triggers.sql
psql "$DATABASE_URL" -f sql/05_dashboard_views.sql
```

O script `03_transform_core_from_staging.sql` deve ser executado depois que o staging estiver carregado pelo ETL Python.
O script `04_functions_triggers.sql` deve ser aplicado depois da primeira carga histórica para evitar ruído de auditoria durante o ETL inicial.

## Teste rápido

```bash
psql "$DATABASE_URL" -f sql/98_smoke_tests.sql
```

O smoke test roda em transação com `ROLLBACK`.

## Camadas

- `staging`: dados brutos preservados com as 43 colunas originais normalizadas para snake case.
- `core`: dimensões, tabela fato tipada e controle de carga.
- `audit`: registros de auditoria com snapshots em JSONB.
- `analytics`: funções e views para consultas epidemiológicas e dashboard.
