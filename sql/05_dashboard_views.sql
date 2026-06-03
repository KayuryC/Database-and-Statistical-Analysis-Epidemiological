BEGIN;

CREATE OR REPLACE VIEW analytics.vw_serie_temporal_semanal AS
SELECT
    (nz.sem_pri / 100)::SMALLINT AS ano_epidemiologico,
    (nz.sem_pri % 100)::SMALLINT AS semana_epidemiologica,
    nz.sem_pri,
    COUNT(*) AS total_notificacoes,
    COUNT(*) FILTER (WHERE nz.classi_fin_codigo = 1) AS casos_confirmados,
    COUNT(*) FILTER (WHERE nz.classi_fin_codigo = 0) AS casos_descartados,
    COUNT(*) FILTER (WHERE nz.classi_fin_codigo IN (2, 8)) AS casos_em_investigacao_ou_inconclusivos,
    COUNT(*) FILTER (WHERE nz.evolucao_codigo IN (2, 3)) AS obitos,
    MIN(nz.dt_sin_pri) AS primeira_data_sintomas,
    MAX(nz.dt_sin_pri) AS ultima_data_sintomas
FROM core.notificacao_zika nz
WHERE nz.sem_pri IS NOT NULL
GROUP BY nz.sem_pri
ORDER BY nz.sem_pri;

COMMENT ON VIEW analytics.vw_serie_temporal_semanal IS
    'Série temporal por semana epidemiológica dos primeiros sintomas.';

CREATE OR REPLACE VIEW analytics.vw_casos_uf_ano AS
SELECT
    nz.nu_ano AS ano,
    nz.uf_residencia AS codigo_uf,
    uf.sigla AS sigla_uf,
    uf.nome AS nome_uf,
    uf.regiao,
    COUNT(*) AS total_notificacoes,
    COUNT(*) FILTER (WHERE nz.classi_fin_codigo = 1) AS casos_confirmados,
    COUNT(*) FILTER (WHERE nz.classi_fin_codigo = 0) AS casos_descartados,
    COUNT(*) FILTER (WHERE nz.classi_fin_codigo IN (2, 8)) AS casos_em_investigacao_ou_inconclusivos,
    COUNT(*) FILTER (WHERE nz.evolucao_codigo IN (2, 3)) AS obitos,
    COUNT(*) FILTER (WHERE nz.is_duplicate) AS duplicatas_marcadas
FROM core.notificacao_zika nz
LEFT JOIN core.dim_uf uf ON uf.codigo_uf = nz.uf_residencia
WHERE nz.nu_ano IS NOT NULL
GROUP BY nz.nu_ano, nz.uf_residencia, uf.sigla, uf.nome, uf.regiao
ORDER BY nz.nu_ano, uf.sigla;

COMMENT ON VIEW analytics.vw_casos_uf_ano IS
    'Casos por UF de residência e ano de notificação.';

CREATE OR REPLACE VIEW analytics.vw_piramide_etaria AS
WITH faixas AS (
    SELECT
        nz.sexo_codigo,
        sexo.descricao AS sexo,
        CASE
            WHEN nz.idade_anos < 1 THEN 'Menor de 1'
            WHEN nz.idade_anos BETWEEN 1 AND 4 THEN '1-4'
            WHEN nz.idade_anos BETWEEN 5 AND 9 THEN '5-9'
            WHEN nz.idade_anos BETWEEN 10 AND 14 THEN '10-14'
            WHEN nz.idade_anos BETWEEN 15 AND 19 THEN '15-19'
            WHEN nz.idade_anos BETWEEN 20 AND 29 THEN '20-29'
            WHEN nz.idade_anos BETWEEN 30 AND 39 THEN '30-39'
            WHEN nz.idade_anos BETWEEN 40 AND 49 THEN '40-49'
            WHEN nz.idade_anos BETWEEN 50 AND 59 THEN '50-59'
            WHEN nz.idade_anos BETWEEN 60 AND 69 THEN '60-69'
            WHEN nz.idade_anos BETWEEN 70 AND 79 THEN '70-79'
            ELSE '80+'
        END AS faixa_etaria,
        CASE
            WHEN nz.idade_anos < 1 THEN 0
            WHEN nz.idade_anos BETWEEN 1 AND 4 THEN 1
            WHEN nz.idade_anos BETWEEN 5 AND 9 THEN 2
            WHEN nz.idade_anos BETWEEN 10 AND 14 THEN 3
            WHEN nz.idade_anos BETWEEN 15 AND 19 THEN 4
            WHEN nz.idade_anos BETWEEN 20 AND 29 THEN 5
            WHEN nz.idade_anos BETWEEN 30 AND 39 THEN 6
            WHEN nz.idade_anos BETWEEN 40 AND 49 THEN 7
            WHEN nz.idade_anos BETWEEN 50 AND 59 THEN 8
            WHEN nz.idade_anos BETWEEN 60 AND 69 THEN 9
            WHEN nz.idade_anos BETWEEN 70 AND 79 THEN 10
            ELSE 11
        END AS ordem_faixa,
        nz.classi_fin_codigo
    FROM core.notificacao_zika nz
    LEFT JOIN core.dim_sexo sexo ON sexo.codigo = nz.sexo_codigo
    WHERE nz.idade_anos IS NOT NULL
      AND nz.sexo_codigo IS NOT NULL
)
SELECT
    faixa_etaria,
    ordem_faixa,
    sexo_codigo,
    sexo,
    COUNT(*) AS total_notificacoes,
    COUNT(*) FILTER (WHERE classi_fin_codigo = 1) AS casos_confirmados
FROM faixas
GROUP BY faixa_etaria, ordem_faixa, sexo_codigo, sexo
ORDER BY ordem_faixa, sexo_codigo;

COMMENT ON VIEW analytics.vw_piramide_etaria IS
    'Distribuição etária por sexo, com destaque para casos confirmados.';

CREATE OR REPLACE VIEW analytics.vw_vigilancia_gestantes AS
SELECT
    nz.nu_ano AS ano,
    nz.uf_residencia AS codigo_uf,
    uf.sigla AS sigla_uf,
    gest.descricao AS situacao_gestacional,
    COUNT(*) AS total_notificacoes_gestantes,
    COUNT(*) FILTER (WHERE nz.classi_fin_codigo = 1) AS gestantes_confirmadas,
    COUNT(*) FILTER (WHERE nz.criterio_codigo = 1) AS confirmacao_laboratorial,
    COUNT(*) FILTER (WHERE nz.criterio_codigo = 2) AS confirmacao_clinico_epidemiologica,
    COUNT(*) FILTER (WHERE nz.evolucao_codigo IN (2, 3)) AS obitos
FROM core.notificacao_zika nz
LEFT JOIN core.dim_uf uf ON uf.codigo_uf = nz.uf_residencia
LEFT JOIN core.dim_gestante gest ON gest.codigo = nz.gestante_codigo
WHERE nz.gestante_codigo IN (1, 2, 3, 4)
GROUP BY nz.nu_ano, nz.uf_residencia, uf.sigla, gest.descricao
ORDER BY nz.nu_ano, uf.sigla, gest.descricao;

COMMENT ON VIEW analytics.vw_vigilancia_gestantes IS
    'Vigilância de notificações em gestantes por ano, UF e idade gestacional.';

CREATE OR REPLACE VIEW analytics.vw_kpi_cards AS
SELECT
    'total_notificacoes' AS kpi,
    'Total de notificações' AS descricao,
    COUNT(*)::NUMERIC AS valor
FROM core.notificacao_zika
UNION ALL
SELECT
    'casos_confirmados',
    'Casos confirmados',
    COUNT(*) FILTER (WHERE classi_fin_codigo = 1)::NUMERIC
FROM core.notificacao_zika
UNION ALL
SELECT
    'obitos',
    'Óbitos registrados',
    COUNT(*) FILTER (WHERE evolucao_codigo IN (2, 3))::NUMERIC
FROM core.notificacao_zika
UNION ALL
SELECT
    'gestantes_confirmadas',
    'Gestantes confirmadas',
    COUNT(*) FILTER (
        WHERE classi_fin_codigo = 1
          AND gestante_codigo IN (1, 2, 3, 4)
    )::NUMERIC
FROM core.notificacao_zika
UNION ALL
SELECT
    'duplicatas_marcadas',
    'Duplicatas completas marcadas',
    COUNT(*) FILTER (WHERE is_duplicate)::NUMERIC
FROM core.notificacao_zika
UNION ALL
SELECT
    'latencia_media_notificacao_dias',
    'Latência média entre sintomas e notificação em dias',
    ROUND(AVG(dt_notific - dt_sin_pri), 2)::NUMERIC
FROM core.notificacao_zika
WHERE dt_notific IS NOT NULL
  AND dt_sin_pri IS NOT NULL
  AND dt_notific >= dt_sin_pri;

COMMENT ON VIEW analytics.vw_kpi_cards IS
    'Indicadores sintéticos para cards de dashboard.';

COMMIT;
