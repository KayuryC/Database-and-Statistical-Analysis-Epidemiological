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

## Próximas etapas

1. Implementar funções e triggers.
2. Construir views epidemiológicas para dashboard.
3. Executar análises estatísticas e documentar resultados.
