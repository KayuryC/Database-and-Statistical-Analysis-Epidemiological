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

## Próximas etapas

1. Consolidar o catálogo de variáveis em `docs/variaveis.md`.
2. Definir o modelo relacional em PostgreSQL.
3. Criar scripts de limpeza e carga.
4. Construir consultas epidemiológicas e análises estatísticas.
