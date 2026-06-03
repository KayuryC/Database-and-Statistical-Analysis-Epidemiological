BEGIN;

SELECT core.fn_decode_idade_sinan('4025') AS idade_25_anos;
SELECT core.fn_decode_idade_sinan('3006') AS idade_6_meses;
SELECT * FROM analytics.fn_resumo_epidemiologico_uf_ano(NULL, NULL) LIMIT 5;
SELECT * FROM core.fn_detectar_duplicatas() LIMIT 5;

SELECT core.fn_inserir_notificacao_validada(
    '{
        "arquivo_origem": "smoke_test",
        "ano_arquivo": "2026",
        "tp_not": "2",
        "id_agravo": "A928",
        "dt_notific": "2026-01-02",
        "sem_not": "202601",
        "nu_ano": "2026",
        "uf_notificacao": "15",
        "municipio_notificacao": "150140",
        "dt_sin_pri": "2026-01-01",
        "sem_pri": "202601",
        "nu_idade_n": "4025",
        "sexo_codigo": "F",
        "gestante_codigo": "5",
        "raca_codigo": "4",
        "escolaridade_codigo": "6",
        "uf_residencia": "15",
        "municipio_residencia": "150140",
        "classi_fin_codigo": "1",
        "criterio_codigo": "1",
        "evolucao_codigo": "1",
        "dt_encerra": "2026-01-10"
    }'::JSONB
) AS notificacao_teste_id;

DO $$
BEGIN
    BEGIN
        PERFORM core.fn_inserir_notificacao_validada(
            '{
                "arquivo_origem": "smoke_test_invalido",
                "ano_arquivo": "2026",
                "tp_not": "2",
                "id_agravo": "A928",
                "dt_notific": "2026-01-02",
                "nu_ano": "2026",
                "uf_notificacao": "15",
                "dt_sin_pri": "2026-01-01",
                "nu_idade_n": "4025",
                "sexo_codigo": "F",
                "gestante_codigo": "5",
                "uf_residencia": "15",
                "classi_fin_codigo": "1",
                "criterio_codigo": "1",
                "evolucao_codigo": "2"
            }'::JSONB
        );
        RAISE EXCEPTION 'Teste de validação clínica deveria falhar.';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM = 'Teste de validação clínica deveria falhar.' THEN
            RAISE;
        END IF;
    END;
END
$$;

ROLLBACK;
