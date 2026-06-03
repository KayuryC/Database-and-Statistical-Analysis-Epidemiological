BEGIN;

CREATE TABLE IF NOT EXISTS audit.validation_log (
    validation_id BIGSERIAL PRIMARY KEY,
    schema_name TEXT NOT NULL,
    table_name TEXT NOT NULL,
    operation TEXT NOT NULL,
    row_pk TEXT,
    issues TEXT[] NOT NULL,
    record_data JSONB NOT NULL,
    detected_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS ix_validation_log_table_time
    ON audit.validation_log (schema_name, table_name, detected_at DESC);

CREATE OR REPLACE FUNCTION core.fn_decode_idade_sinan(p_nu_idade_n TEXT)
RETURNS INTEGER
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    clean_value TEXT;
    unidade SMALLINT;
    quantidade INTEGER;
BEGIN
    clean_value := NULLIF(BTRIM(p_nu_idade_n), '');

    IF clean_value IS NULL OR clean_value !~ '^[1234][0-9]{3}$' THEN
        RETURN NULL;
    END IF;

    unidade := SUBSTRING(clean_value FROM 1 FOR 1)::SMALLINT;
    quantidade := SUBSTRING(clean_value FROM 2)::INTEGER;

    IF unidade = 1 THEN
        RETURN 0;
    ELSIF unidade = 2 THEN
        RETURN 0;
    ELSIF unidade = 3 THEN
        RETURN FLOOR(quantidade / 12.0)::INTEGER;
    ELSIF unidade = 4 THEN
        RETURN quantidade;
    END IF;

    RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION analytics.fn_resumo_epidemiologico_uf_ano(
    p_codigo_uf SMALLINT DEFAULT NULL,
    p_ano SMALLINT DEFAULT NULL
)
RETURNS TABLE (
    ano SMALLINT,
    codigo_uf SMALLINT,
    sigla_uf CHAR(2),
    total_notificacoes BIGINT,
    casos_confirmados BIGINT,
    casos_descartados BIGINT,
    casos_em_investigacao_ou_inconclusivos BIGINT,
    obitos BIGINT,
    gestantes_confirmadas BIGINT
)
LANGUAGE sql
STABLE
AS $$
    SELECT
        nz.nu_ano AS ano,
        nz.uf_residencia AS codigo_uf,
        uf.sigla AS sigla_uf,
        COUNT(*) AS total_notificacoes,
        COUNT(*) FILTER (WHERE nz.classi_fin_codigo = 1) AS casos_confirmados,
        COUNT(*) FILTER (WHERE nz.classi_fin_codigo = 0) AS casos_descartados,
        COUNT(*) FILTER (WHERE nz.classi_fin_codigo IN (2, 8)) AS casos_em_investigacao_ou_inconclusivos,
        COUNT(*) FILTER (WHERE nz.evolucao_codigo IN (2, 3)) AS obitos,
        COUNT(*) FILTER (
            WHERE nz.classi_fin_codigo = 1
              AND nz.gestante_codigo IN (1, 2, 3, 4)
        ) AS gestantes_confirmadas
    FROM core.notificacao_zika nz
    LEFT JOIN core.dim_uf uf ON uf.codigo_uf = nz.uf_residencia
    WHERE (p_codigo_uf IS NULL OR nz.uf_residencia = p_codigo_uf)
      AND (p_ano IS NULL OR nz.nu_ano = p_ano)
    GROUP BY nz.nu_ano, nz.uf_residencia, uf.sigla
    ORDER BY nz.nu_ano, uf.sigla;
$$;

CREATE OR REPLACE FUNCTION core.fn_detectar_duplicatas()
RETURNS TABLE (
    row_hash TEXT,
    quantidade BIGINT,
    notificacao_ids BIGINT[],
    raw_ids BIGINT[]
)
LANGUAGE sql
STABLE
AS $$
    SELECT
        nz.row_hash,
        COUNT(*) AS quantidade,
        ARRAY_AGG(nz.notificacao_id ORDER BY nz.notificacao_id) AS notificacao_ids,
        ARRAY_AGG(nz.raw_id ORDER BY nz.raw_id) FILTER (WHERE nz.raw_id IS NOT NULL) AS raw_ids
    FROM core.notificacao_zika nz
    GROUP BY nz.row_hash
    HAVING COUNT(*) > 1
    ORDER BY quantidade DESC, row_hash;
$$;

CREATE OR REPLACE FUNCTION core.fn_set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION audit.fn_audit_notificacao_zika()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    record_pk TEXT;
BEGIN
    IF TG_OP = 'DELETE' THEN
        record_pk := OLD.notificacao_id::TEXT;
    ELSE
        record_pk := NEW.notificacao_id::TEXT;
    END IF;

    INSERT INTO audit.audit_log (
        schema_name,
        table_name,
        operation,
        row_pk,
        old_data,
        new_data
    )
    VALUES (
        TG_TABLE_SCHEMA,
        TG_TABLE_NAME,
        TG_OP,
        record_pk,
        CASE WHEN TG_OP IN ('UPDATE', 'DELETE') THEN TO_JSONB(OLD) END,
        CASE WHEN TG_OP IN ('INSERT', 'UPDATE') THEN TO_JSONB(NEW) END
    );

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION core.fn_validar_notificacao_clinica()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    issues TEXT[] := ARRAY[]::TEXT[];
    strict_validation BOOLEAN;
BEGIN
    strict_validation := COALESCE(
        LOWER(current_setting('core.strict_clinical_validation', TRUE)),
        'off'
    ) IN ('on', 'true', '1', 'yes');

    IF NEW.evolucao_codigo IN (2, 3) AND NEW.dt_obito IS NULL THEN
        issues := ARRAY_APPEND(issues, 'Evolução de óbito exige DT_OBITO preenchida.');
    END IF;

    IF NEW.dt_obito IS NOT NULL
       AND NEW.dt_sin_pri IS NOT NULL
       AND NEW.dt_obito < NEW.dt_sin_pri THEN
        issues := ARRAY_APPEND(issues, 'DT_OBITO não pode ser anterior a DT_SIN_PRI.');
    END IF;

    IF NEW.gestante_codigo IN (1, 2, 3, 4)
       AND NEW.sexo_codigo IS NOT NULL
       AND NEW.sexo_codigo <> 'F' THEN
        issues := ARRAY_APPEND(issues, 'Gestante deve ter CS_SEXO feminino ou sexo não informado.');
    END IF;

    IF NEW.dt_encerra IS NOT NULL
       AND NEW.dt_notific IS NOT NULL
       AND NEW.dt_encerra < NEW.dt_notific THEN
        issues := ARRAY_APPEND(issues, 'DT_ENCERRA não pode ser anterior a DT_NOTIFIC.');
    END IF;

    IF ARRAY_LENGTH(issues, 1) IS NOT NULL THEN
        IF strict_validation THEN
            RAISE EXCEPTION 'Notificação clinicamente inconsistente: %', ARRAY_TO_STRING(issues, ' | ');
        END IF;

        INSERT INTO audit.validation_log (
            schema_name,
            table_name,
            operation,
            row_pk,
            issues,
            record_data
        )
        VALUES (
            TG_TABLE_SCHEMA,
            TG_TABLE_NAME,
            TG_OP,
            NEW.notificacao_id::TEXT,
            issues,
            TO_JSONB(NEW)
        );
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION core.fn_inserir_notificacao_validada(p_notificacao JSONB)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    new_id BIGINT;
    clean_idade TEXT;
    idade_unidade SMALLINT;
    idade_quantidade SMALLINT;
BEGIN
    PERFORM set_config('core.strict_clinical_validation', 'on', TRUE);

    clean_idade := NULLIF(BTRIM(p_notificacao->>'nu_idade_n'), '');
    IF clean_idade ~ '^[1234][0-9]{3}$' THEN
        idade_unidade := SUBSTRING(clean_idade FROM 1 FOR 1)::SMALLINT;
        idade_quantidade := SUBSTRING(clean_idade FROM 2)::SMALLINT;
    END IF;

    INSERT INTO core.notificacao_zika (
        arquivo_origem,
        ano_arquivo,
        tp_not,
        id_agravo,
        dt_notific,
        sem_not,
        nu_ano,
        uf_notificacao,
        municipio_notificacao,
        dt_sin_pri,
        sem_pri,
        nu_idade_n,
        idade_unidade,
        idade_quantidade,
        idade_anos,
        sexo_codigo,
        gestante_codigo,
        raca_codigo,
        escolaridade_codigo,
        uf_residencia,
        municipio_residencia,
        classi_fin_codigo,
        criterio_codigo,
        evolucao_codigo,
        dt_obito,
        dt_encerra,
        row_hash,
        is_duplicate
    )
    VALUES (
        COALESCE(NULLIF(p_notificacao->>'arquivo_origem', ''), 'insercao_validada'),
        NULLIF(p_notificacao->>'ano_arquivo', '')::SMALLINT,
        NULLIF(p_notificacao->>'tp_not', '')::SMALLINT,
        NULLIF(p_notificacao->>'id_agravo', ''),
        NULLIF(p_notificacao->>'dt_notific', '')::DATE,
        NULLIF(p_notificacao->>'sem_not', '')::INTEGER,
        NULLIF(p_notificacao->>'nu_ano', '')::SMALLINT,
        NULLIF(p_notificacao->>'uf_notificacao', '')::SMALLINT,
        NULLIF(p_notificacao->>'municipio_notificacao', '')::INTEGER,
        NULLIF(p_notificacao->>'dt_sin_pri', '')::DATE,
        NULLIF(p_notificacao->>'sem_pri', '')::INTEGER,
        clean_idade,
        idade_unidade,
        idade_quantidade,
        core.fn_decode_idade_sinan(clean_idade),
        NULLIF(UPPER(p_notificacao->>'sexo_codigo'), ''),
        NULLIF(p_notificacao->>'gestante_codigo', '')::SMALLINT,
        NULLIF(p_notificacao->>'raca_codigo', '')::SMALLINT,
        NULLIF(p_notificacao->>'escolaridade_codigo', '')::SMALLINT,
        NULLIF(p_notificacao->>'uf_residencia', '')::SMALLINT,
        NULLIF(p_notificacao->>'municipio_residencia', '')::INTEGER,
        NULLIF(p_notificacao->>'classi_fin_codigo', '')::SMALLINT,
        NULLIF(p_notificacao->>'criterio_codigo', '')::SMALLINT,
        NULLIF(p_notificacao->>'evolucao_codigo', '')::SMALLINT,
        NULLIF(p_notificacao->>'dt_obito', '')::DATE,
        NULLIF(p_notificacao->>'dt_encerra', '')::DATE,
        COALESCE(NULLIF(p_notificacao->>'row_hash', ''), MD5(p_notificacao::TEXT)),
        FALSE
    )
    RETURNING notificacao_id INTO new_id;

    RETURN new_id;
END;
$$;

DROP TRIGGER IF EXISTS trg_notificacao_zika_updated_at ON core.notificacao_zika;
CREATE TRIGGER trg_notificacao_zika_updated_at
BEFORE UPDATE ON core.notificacao_zika
FOR EACH ROW
EXECUTE FUNCTION core.fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_notificacao_zika_validacao_clinica ON core.notificacao_zika;
CREATE TRIGGER trg_notificacao_zika_validacao_clinica
BEFORE INSERT OR UPDATE ON core.notificacao_zika
FOR EACH ROW
EXECUTE FUNCTION core.fn_validar_notificacao_clinica();

DROP TRIGGER IF EXISTS trg_notificacao_zika_audit ON core.notificacao_zika;
CREATE TRIGGER trg_notificacao_zika_audit
AFTER INSERT OR UPDATE OR DELETE ON core.notificacao_zika
FOR EACH ROW
EXECUTE FUNCTION audit.fn_audit_notificacao_zika();

COMMIT;
