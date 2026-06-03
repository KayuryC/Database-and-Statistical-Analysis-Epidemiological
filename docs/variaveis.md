# Catálogo de Variáveis — Zika/SINAN 2018–2026

Este catálogo documenta as 43 colunas da base `ZIKA_BR_2018_2026_UNIFICADO.csv`.
Cada linha da base representa uma ficha individual de notificação de Zika no SINAN.

## Observações metodológicas

- Para curvas epidêmicas, priorizar `DT_SIN_PRI` ou `SEM_PRI`, pois representam o início dos sintomas.
- Para casos confirmados, filtrar `CLASSI_FIN = 1`.
- Não tratar vazios, códigos de ignorado (`9`) e marcadores internos como zero epidemiológico.
- Distinguir local de notificação (`SG_UF_NOT`, `ID_MUNICIP`), residência (`SG_UF`, `ID_MN_RESI`) e provável infecção (`COUFINF`, `COMUNINF`).
- Preservar `arquivo_origem` e `ano_arquivo` para rastreabilidade, pois arquivos SINAN podem receber atualizações retrospectivas.

## Colunas da base

| Coluna | Nome completo | Tipo esperado | Uso no projeto |
|---|---|---|---|
| `arquivo_origem` | Arquivo de origem | texto | Rastrear o `.dbc` original usado na unificação. |
| `ano_arquivo` | Ano do arquivo de origem | inteiro | Rastrear o ano-base do arquivo, sem assumir ano de ocorrência. |
| `TP_NOT` | Tipo de notificação | categoria | Identificar notificação individual; nesta base, valor esperado `2`. |
| `ID_AGRAVO` | Código do agravo CID-10 | categoria | Identificar Zika por `A92.` ou `A928`. |
| `CS_SUSPEIT` | Caso suspeito | categoria | Campo quase sempre vazio; preservar no staging. |
| `DT_NOTIFIC` | Data da notificação | data | Medir entrada da ficha no SINAN. |
| `SEM_NOT` | Semana epidemiológica da notificação | inteiro | Agregação temporal por semana de notificação. |
| `NU_ANO` | Ano da notificação | inteiro | Ano em que a notificação foi registrada. |
| `SG_UF_NOT` | UF de notificação | código IBGE UF | Local onde o caso foi notificado. |
| `ID_MUNICIP` | Município de notificação | código IBGE município | Município da unidade notificadora. |
| `ID_REGIONA` | Regional de saúde de notificação | código | Regional da unidade notificadora. |
| `DT_SIN_PRI` | Data dos primeiros sintomas | data | Principal data para curva epidêmica. |
| `SEM_PRI` | Semana epidemiológica dos sintomas | inteiro | Principal semana para série temporal epidemiológica. |
| `NU_IDADE_N` | Idade codificada SINAN | categoria | Converter para idade aproximada em anos. |
| `CS_SEXO` | Sexo | categoria | Dimensão demográfica. |
| `CS_GESTANT` | Idade gestacional | categoria | Vigilância de gestantes e risco congênito. |
| `CS_RACA` | Raça/cor autodeclarada | categoria | Dimensão sociodemográfica. |
| `CS_ESCOL_N` | Escolaridade | categoria | Dimensão sociodemográfica; pode vir com zero à esquerda. |
| `SG_UF` | UF de residência | código IBGE UF | Local de residência do paciente. |
| `ID_MN_RESI` | Município de residência | código IBGE município | Município de residência do paciente. |
| `ID_RG_RESI` | Regional de residência | código | Regional de saúde da residência. |
| `ID_PAIS` | País de residência | código | País de residência; `1` indica Brasil. |
| `NDUPLIC_N` | Notificação duplicada | categoria | Marcador interno de duplicidade. |
| `IN_VINCULA` | Caso vinculado | categoria | Marcador interno de vinculação a outro caso/surto. |
| `DT_INVEST` | Data da investigação | data | Início da investigação epidemiológica. |
| `ID_OCUPA_N` | Ocupação | código CBO | Ocupação do paciente; alta proporção de vazios. |
| `CLASSI_FIN` | Classificação final | categoria | Define confirmados, descartados e investigação. |
| `CRITERIO` | Critério de confirmação/descarte | categoria | Laboratorial ou clínico-epidemiológico. |
| `TPAUTOCTO` | Autoctonia | categoria | Infecção local, importada ou indeterminada. |
| `COUFINF` | UF provável de infecção | código IBGE UF | UF provável onde a infecção ocorreu. |
| `COPAISINF` | País provável de infecção | código/texto | País provável de infecção; preservar variações observadas. |
| `COMUNINF` | Município provável de infecção | código IBGE município | Município provável onde a infecção ocorreu. |
| `DOENCA_TRA` | Doença relacionada ao trabalho | categoria | Indica relação ocupacional. |
| `EVOLUCAO` | Evolução do caso | categoria | Cura, óbito pelo agravo, óbito por outra causa ou ignorado. |
| `DT_OBITO` | Data do óbito | data | Preenchida quando há óbito. |
| `DT_ENCERRA` | Data de encerramento | data | Data de encerramento do caso no sistema. |
| `CS_FLXRET` | Fluxo de retorno | categoria interna | Controle interno de fluxo; preservar para auditoria. |
| `FLXRECEBI` | Fluxo recebido | categoria interna | Controle interno de recebimento; preservar para auditoria. |
| `TP_SISTEMA` | Tipo de sistema | categoria interna | Sistema de origem do registro. |
| `TPUNINOT` | Tipo de unidade notificadora | categoria | Tipo do estabelecimento notificante. |
| `ID_UNIDADE` | Código da unidade notificadora | código CNES | Unidade de saúde que notificou. |
| `ANO_NASC` | Ano de nascimento | inteiro | Apoio à validação da idade. |
| `DT_DIGITA` | Data de digitação | data | Data em que o registro foi digitado no SINAN. |

## Domínios categóricos principais

### Unidade Federativa

| Código | UF | Código | UF | Código | UF |
|---:|---|---:|---|---:|---|
| 11 | RO | 12 | AC | 13 | AM |
| 14 | RR | 15 | PA | 16 | AP |
| 17 | TO | 21 | MA | 22 | PI |
| 23 | CE | 24 | RN | 25 | PB |
| 26 | PE | 27 | AL | 28 | SE |
| 29 | BA | 31 | MG | 32 | ES |
| 33 | RJ | 35 | SP | 41 | PR |
| 42 | SC | 43 | RS | 50 | MS |
| 51 | MT | 52 | GO | 53 | DF |

### Sexo (`CS_SEXO`)

| Código | Descrição |
|---|---|
| `M` | Masculino |
| `F` | Feminino |
| `I` | Ignorado |

### Gestante (`CS_GESTANT`)

| Código | Descrição |
|---:|---|
| 1 | 1º trimestre |
| 2 | 2º trimestre |
| 3 | 3º trimestre |
| 4 | Idade gestacional ignorada |
| 5 | Não |
| 6 | Não se aplica |
| 9 | Ignorado |

### Raça/cor (`CS_RACA`)

| Código | Descrição |
|---:|---|
| 1 | Branca |
| 2 | Preta |
| 3 | Amarela |
| 4 | Parda |
| 5 | Indígena |
| 9 | Ignorado |

### Escolaridade (`CS_ESCOL_N`)

| Código | Descrição |
|---:|---|
| 0 | Analfabeto |
| 1 | 1ª a 4ª série incompleta do ensino fundamental |
| 2 | 4ª série completa do ensino fundamental |
| 3 | 5ª a 8ª série incompleta do ensino fundamental |
| 4 | Ensino fundamental completo |
| 5 | Ensino médio incompleto |
| 6 | Ensino médio completo |
| 7 | Educação superior incompleta |
| 8 | Educação superior completa |
| 9 | Ignorado |
| 10 | Não se aplica |

### Classificação final (`CLASSI_FIN`)

| Código | Descrição | Regra analítica |
|---:|---|---|
| 0 | Descartado | Excluir de análises de confirmados. |
| 1 | Confirmado | Usar para análises de casos confirmados. |
| 2 | Em investigação | Separar de confirmados. |
| 8 | Inconclusivo | Separar de confirmados. |

### Critério (`CRITERIO`)

| Código | Descrição |
|---:|---|
| 0 | Em investigação |
| 1 | Laboratorial |
| 2 | Clínico-epidemiológico |

### Autoctonia (`TPAUTOCTO`)

| Código | Descrição |
|---:|---|
| 1 | Sim, autóctone |
| 2 | Não, importado |
| 3 | Indeterminado |

### Doença relacionada ao trabalho (`DOENCA_TRA`)

| Código | Descrição |
|---:|---|
| 1 | Sim |
| 2 | Não |
| 9 | Ignorado |

### Evolução (`EVOLUCAO`)

| Código | Descrição |
|---:|---|
| 0 | Em investigação |
| 1 | Cura |
| 2 | Óbito pelo agravo |
| 3 | Óbito por outra causa |
| 9 | Ignorado |

## Decodificação de idade (`NU_IDADE_N`)

O campo é composto por quatro dígitos:

- 1º dígito: unidade de medida (`1` hora, `2` dia, `3` mês, `4` ano).
- Demais dígitos: quantidade naquela unidade.

Exemplos:

| Valor | Interpretação | Idade aproximada em anos |
|---|---|---:|
| `4025` | 25 anos | 25 |
| `3006` | 6 meses | 0 |
| `2015` | 15 dias | 0 |

No banco, a idade decodificada será armazenada como aproximação inteira em anos para agregações epidemiológicas.
