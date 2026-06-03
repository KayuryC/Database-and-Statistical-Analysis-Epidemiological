BEGIN;

CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS core;
CREATE SCHEMA IF NOT EXISTS audit;
CREATE SCHEMA IF NOT EXISTS analytics;

COMMENT ON SCHEMA staging IS 'Camada de ingestão com dados brutos preservados.';
COMMENT ON SCHEMA core IS 'Modelo relacional tipado e normalizado para notificações de Zika.';
COMMENT ON SCHEMA audit IS 'Auditoria de alterações em tabelas críticas.';
COMMENT ON SCHEMA analytics IS 'Views e funções analíticas para consultas epidemiológicas.';

COMMIT;
