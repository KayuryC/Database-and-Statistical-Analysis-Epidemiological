# Checklist de Requisitos da Atividade

Fonte: projeto “Banco de Dados e Análise Estatística Epidemiológica — Zika Vírus (SINAN 2018–2026)”.

## Entregas obrigatórias

| Requisito | Implementação planejada | Status |
|---|---|---|
| Modelagem relacional normalizada | Schemas `staging`, `core`, `audit` e `analytics`; tabelas de domínio e fato tipada. | Planejado |
| Carga ETL via Python | Script `scripts/load_to_postgres.py` com `DATABASE_URL`, modo `reload` e cópia do CSV bruto. | Planejado |
| Função de decodificação de idade | `core.fn_decode_idade_sinan`. | Planejado |
| Função de resumo UF/ano | `analytics.fn_resumo_epidemiologico_uf_ano`. | Planejado |
| Inserção validada | `core.fn_inserir_notificacao_validada`. | Planejado |
| Detecção de duplicatas | `core.fn_detectar_duplicatas`. | Planejado |
| Triggers de auditoria | Snapshot `OLD`/`NEW` em JSONB para `INSERT`, `UPDATE` e `DELETE`. | Planejado |
| Trigger de validação clínica | Consistência entre evolução, óbito, classificação e datas. | Planejado |
| Views para dashboard | Série semanal, UF/ano, pirâmide etária, gestantes e KPIs. | Planejado |
| Análise estatística | Sazonalidade, tendência por UF, previsão e K-Means municipal. | Planejado |

## Critérios de aceite

- Documentar todas as 43 colunas e os domínios principais.
- Preservar a base bruta sem versionar o CSV no Git.
- Carregar 236.398 registros no staging.
- Marcar 288 linhas completamente duplicadas identificadas no perfil inicial.
- Usar `CLASSI_FIN = 1` para análises de confirmados.
- Preferir `DT_SIN_PRI`/`SEM_PRI` em séries epidemiológicas.
- Entregar scripts SQL executáveis em PostgreSQL 15+.
- Entregar scripts Python com mensagens claras de dependências ausentes.

## Organização de branches

Cada etapa deve ser implementada em uma branch `feature-*`, validada, commitada e integrada à `main`.
