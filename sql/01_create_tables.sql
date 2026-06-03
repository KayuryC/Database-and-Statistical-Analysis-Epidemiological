BEGIN;

CREATE TABLE IF NOT EXISTS staging.notificacoes_zika_raw (
    raw_id BIGSERIAL PRIMARY KEY,
    arquivo_origem TEXT,
    ano_arquivo TEXT,
    tp_not TEXT,
    id_agravo TEXT,
    cs_suspeit TEXT,
    dt_notific TEXT,
    sem_not TEXT,
    nu_ano TEXT,
    sg_uf_not TEXT,
    id_municip TEXT,
    id_regiona TEXT,
    dt_sin_pri TEXT,
    sem_pri TEXT,
    nu_idade_n TEXT,
    cs_sexo TEXT,
    cs_gestant TEXT,
    cs_raca TEXT,
    cs_escol_n TEXT,
    sg_uf TEXT,
    id_mn_resi TEXT,
    id_rg_resi TEXT,
    id_pais TEXT,
    nduplic_n TEXT,
    in_vincula TEXT,
    dt_invest TEXT,
    id_ocupa_n TEXT,
    classi_fin TEXT,
    criterio TEXT,
    tpautocto TEXT,
    coufinf TEXT,
    copaisinf TEXT,
    comuninf TEXT,
    doenca_tra TEXT,
    evolucao TEXT,
    dt_obito TEXT,
    dt_encerra TEXT,
    cs_flxret TEXT,
    flxrecebi TEXT,
    tp_sistema TEXT,
    tpuninot TEXT,
    id_unidade TEXT,
    ano_nasc TEXT,
    dt_digita TEXT,
    row_hash TEXT NOT NULL,
    is_duplicate BOOLEAN NOT NULL DEFAULT FALSE,
    loaded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS ix_zika_raw_row_hash ON staging.notificacoes_zika_raw (row_hash);
CREATE INDEX IF NOT EXISTS ix_zika_raw_ano_arquivo ON staging.notificacoes_zika_raw (ano_arquivo);

CREATE TABLE IF NOT EXISTS core.dim_uf (
    codigo_uf SMALLINT PRIMARY KEY,
    sigla CHAR(2) NOT NULL UNIQUE,
    nome TEXT NOT NULL,
    regiao TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS core.dim_sexo (
    codigo TEXT PRIMARY KEY,
    descricao TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS core.dim_gestante (
    codigo SMALLINT PRIMARY KEY,
    descricao TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS core.dim_raca (
    codigo SMALLINT PRIMARY KEY,
    descricao TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS core.dim_escolaridade (
    codigo SMALLINT PRIMARY KEY,
    descricao TEXT NOT NULL,
    ordem SMALLINT NOT NULL
);

CREATE TABLE IF NOT EXISTS core.dim_classificacao_final (
    codigo SMALLINT PRIMARY KEY,
    descricao TEXT NOT NULL,
    usar_como_confirmado BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS core.dim_criterio (
    codigo SMALLINT PRIMARY KEY,
    descricao TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS core.dim_autoctonia (
    codigo SMALLINT PRIMARY KEY,
    descricao TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS core.dim_doenca_trabalho (
    codigo SMALLINT PRIMARY KEY,
    descricao TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS core.dim_evolucao (
    codigo SMALLINT PRIMARY KEY,
    descricao TEXT NOT NULL,
    indica_obito BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS core.notificacao_zika (
    notificacao_id BIGSERIAL PRIMARY KEY,
    raw_id BIGINT UNIQUE REFERENCES staging.notificacoes_zika_raw (raw_id),
    arquivo_origem TEXT NOT NULL,
    ano_arquivo SMALLINT,
    tp_not SMALLINT,
    id_agravo TEXT,
    dt_notific DATE,
    sem_not INTEGER,
    nu_ano SMALLINT,
    uf_notificacao SMALLINT REFERENCES core.dim_uf (codigo_uf),
    municipio_notificacao INTEGER,
    regional_notificacao TEXT,
    dt_sin_pri DATE,
    sem_pri INTEGER,
    nu_idade_n TEXT,
    idade_unidade SMALLINT,
    idade_quantidade SMALLINT,
    idade_anos INTEGER,
    sexo_codigo TEXT REFERENCES core.dim_sexo (codigo),
    gestante_codigo SMALLINT REFERENCES core.dim_gestante (codigo),
    raca_codigo SMALLINT REFERENCES core.dim_raca (codigo),
    escolaridade_codigo SMALLINT REFERENCES core.dim_escolaridade (codigo),
    uf_residencia SMALLINT REFERENCES core.dim_uf (codigo_uf),
    municipio_residencia INTEGER,
    regional_residencia TEXT,
    pais_residencia TEXT,
    nduplic_codigo TEXT,
    in_vincula TEXT,
    dt_invest DATE,
    ocupacao_cbo TEXT,
    classi_fin_codigo SMALLINT REFERENCES core.dim_classificacao_final (codigo),
    criterio_codigo SMALLINT REFERENCES core.dim_criterio (codigo),
    tpautocto_codigo SMALLINT REFERENCES core.dim_autoctonia (codigo),
    uf_infeccao SMALLINT REFERENCES core.dim_uf (codigo_uf),
    pais_infeccao TEXT,
    municipio_infeccao INTEGER,
    doenca_trabalho_codigo SMALLINT REFERENCES core.dim_doenca_trabalho (codigo),
    evolucao_codigo SMALLINT REFERENCES core.dim_evolucao (codigo),
    dt_obito DATE,
    dt_encerra DATE,
    cs_flxret TEXT,
    flxrecebi TEXT,
    tp_sistema TEXT,
    tpuninot TEXT,
    id_unidade TEXT,
    ano_nasc SMALLINT,
    dt_digita DATE,
    row_hash TEXT NOT NULL,
    is_duplicate BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ck_notificacao_zika_idade_anos CHECK (idade_anos IS NULL OR idade_anos BETWEEN 0 AND 130),
    CONSTRAINT ck_notificacao_zika_datas_base CHECK (
        dt_sin_pri IS NULL OR dt_notific IS NULL OR dt_sin_pri <= dt_notific + INTERVAL '365 days'
    )
);

CREATE INDEX IF NOT EXISTS ix_notificacao_zika_row_hash ON core.notificacao_zika (row_hash);
CREATE INDEX IF NOT EXISTS ix_notificacao_zika_confirmados ON core.notificacao_zika (classi_fin_codigo)
    WHERE classi_fin_codigo = 1;
CREATE INDEX IF NOT EXISTS ix_notificacao_zika_sem_pri ON core.notificacao_zika (sem_pri);
CREATE INDEX IF NOT EXISTS ix_notificacao_zika_uf_ano ON core.notificacao_zika (uf_residencia, nu_ano);
CREATE INDEX IF NOT EXISTS ix_notificacao_zika_municipio_residencia ON core.notificacao_zika (municipio_residencia);

CREATE TABLE IF NOT EXISTS core.etl_load_log (
    load_id BIGSERIAL PRIMARY KEY,
    source_file TEXT NOT NULL,
    mode TEXT NOT NULL,
    started_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    finished_at TIMESTAMPTZ,
    rows_loaded INTEGER,
    rows_inserted_core INTEGER,
    status TEXT NOT NULL DEFAULT 'running',
    notes TEXT
);

CREATE TABLE IF NOT EXISTS audit.audit_log (
    audit_id BIGSERIAL PRIMARY KEY,
    schema_name TEXT NOT NULL,
    table_name TEXT NOT NULL,
    operation TEXT NOT NULL,
    row_pk TEXT,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    changed_by TEXT NOT NULL DEFAULT CURRENT_USER,
    old_data JSONB,
    new_data JSONB
);

CREATE INDEX IF NOT EXISTS ix_audit_log_table_time ON audit.audit_log (schema_name, table_name, changed_at DESC);

COMMIT;
