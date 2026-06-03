# Checklist de Requisitos da Atividade

Fonte: projeto “Banco de Dados e Análise Estatística Epidemiológica — Zika Vírus (SINAN 2018–2026)”.

## Entregas obrigatórias

| Requisito | Implementação entregue | Status |
|---|---|---|
| Modelagem relacional normalizada | Schemas `staging`, `core`, `audit` e `analytics`; tabelas de domínio e fato tipada. | Implementado |
| Carga ETL via Python | `scripts/load_to_postgres.py` com `DATABASE_URL`, modo `reload`, staging e transformação para core. | Implementado |
| Função de decodificação de idade | `core.fn_decode_idade_sinan`. | Implementado |
| Função de resumo UF/ano | `analytics.fn_resumo_epidemiologico_uf_ano`. | Implementado |
| Inserção validada | `core.fn_inserir_notificacao_validada` com JSONB e validação clínica estrita. | Implementado |
| Detecção de duplicatas | `core.fn_detectar_duplicatas`. | Implementado |
| Triggers de auditoria | `trg_notificacao_zika_audit` com snapshot `OLD`/`NEW` em JSONB. | Implementado |
| Trigger de validação clínica | `trg_notificacao_zika_validacao_clinica`, com log e modo estrito para inserção validada. | Implementado |
| Views para dashboard | Série semanal, UF/ano, pirâmide etária, gestantes e KPIs. | Implementado |
| Análise estatística | Sazonalidade, tendência por UF, previsão com Prophet quando instalado e K-Means municipal. | Implementado |

## Critérios de aceite

- Documentar todas as 43 colunas e os domínios principais.
- Preservar a base bruta sem versionar o CSV no Git.
- Carregar 236.398 registros no staging.
- Marcar 288 linhas completamente duplicadas identificadas no perfil inicial.
- Usar `CLASSI_FIN = 1` para análises de confirmados.
- Preferir `DT_SIN_PRI`/`SEM_PRI` em séries epidemiológicas.
- Entregar scripts SQL executáveis em PostgreSQL 15+.
- Entregar scripts Python com mensagens claras de dependências ausentes.

## Validações já executadas

- `python3 scripts/profile_csv.py`
- `python3 scripts/load_to_postgres.py --help`
- `python3 scripts/run_statistical_analysis.py --source csv`
- `python3 -m py_compile` nos scripts Python do projeto, com cache local.

## Validações pendentes no ambiente do usuário

- Instalar PostgreSQL 15+ e `psql`.
- Instalar dependências de `requirements.txt`, especialmente `psycopg[binary]` e `prophet`.
- Executar ETL real no banco `zika_sinan`.
- Executar `sql/98_smoke_tests.sql`.

## Organização de branches

Cada etapa foi implementada em branch `feature-*`, commitada, enviada ao remoto e integrada à `main`.
