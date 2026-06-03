# Database and Statistical Analysis Epidemiological

Projeto para transformar a base bruta de Zika Vírus do SINAN em um banco relacional normalizado no PostgreSQL, com automação, documentação e análises estatísticas aplicadas à saúde pública.

## Estrutura inicial

```text
data/
  raw/          # CSVs brutos, não versionados
  processed/    # bases derivadas, não versionadas
docs/
  reports/      # relatórios gerados pelos scripts
scripts/        # automações em Python
sql/            # scripts SQL do modelo e das análises
```

## Entregas implementadas

- Catálogo das 43 variáveis em `docs/variaveis.md`.
- Checklist da atividade em `docs/requisitos.md`.
- Modelagem relacional em `docs/modelagem.md`.
- ETL PostgreSQL em `scripts/load_to_postgres.py`.
- Funções, triggers, auditoria e validação clínica em `sql/04_functions_triggers.sql`.
- Views para dashboard em `sql/05_dashboard_views.sql`.
- Análise estatística em `scripts/run_statistical_analysis.py`.
- Guia de reprodução em `docs/execucao.md`.

## Base bruta

O CSV unificado deve ficar em:

```text
data/raw/ZIKA_BR_2018_2026_UNIFICADO.csv
```

Por enquanto, os arquivos `.csv` ficam ignorados pelo Git para evitar commits grandes/acidentais. A análise versionada começa pelos scripts e relatórios.

## Diagnóstico inicial

Gerar o perfil da base:

```bash
python3 scripts/profile_csv.py
```

O relatório será criado em:

```text
docs/reports/perfil_csv_zika.md
```

## Ambiente Python

Instalar dependências:

```bash
python3 -m pip install -r requirements.txt
```

## Carga PostgreSQL

Configurar a URL do banco local:

```bash
export DATABASE_URL="postgresql://usuario:senha@localhost:5432/zika_sinan"
```

Executar a carga completa:

```bash
python3 scripts/load_to_postgres.py --database-url "$DATABASE_URL" --csv data/raw/ZIKA_BR_2018_2026_UNIFICADO.csv --mode reload
```

O script cria schemas/tabelas/dimensões, carrega o staging, transforma os registros para `core.notificacao_zika` e marca duplicatas completas por `row_hash`.

Depois da carga histórica, aplicar funções, triggers e views:

```bash
psql "$DATABASE_URL" -f sql/04_functions_triggers.sql
psql "$DATABASE_URL" -f sql/05_dashboard_views.sql
psql "$DATABASE_URL" -f sql/98_smoke_tests.sql
```

## Análise estatística

Gerar relatório estatístico:

```bash
python3 scripts/run_statistical_analysis.py --database-url "$DATABASE_URL" --output docs/reports/analise_estatistica.md
```

Se o PostgreSQL ou o driver não estiverem disponíveis, o script pode usar o CSV bruto como fallback:

```bash
python3 scripts/run_statistical_analysis.py --source csv
```

## Próximas etapas

1. Instalar PostgreSQL 15+ localmente, se ainda não estiver instalado.
2. Executar a carga completa e o smoke test SQL.
3. Revisar os relatórios em `docs/reports/`.
