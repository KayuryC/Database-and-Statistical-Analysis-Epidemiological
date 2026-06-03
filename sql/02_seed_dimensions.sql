BEGIN;

INSERT INTO core.dim_uf (codigo_uf, sigla, nome, regiao) VALUES
    (11, 'RO', 'Rondônia', 'Norte'),
    (12, 'AC', 'Acre', 'Norte'),
    (13, 'AM', 'Amazonas', 'Norte'),
    (14, 'RR', 'Roraima', 'Norte'),
    (15, 'PA', 'Pará', 'Norte'),
    (16, 'AP', 'Amapá', 'Norte'),
    (17, 'TO', 'Tocantins', 'Norte'),
    (21, 'MA', 'Maranhão', 'Nordeste'),
    (22, 'PI', 'Piauí', 'Nordeste'),
    (23, 'CE', 'Ceará', 'Nordeste'),
    (24, 'RN', 'Rio Grande do Norte', 'Nordeste'),
    (25, 'PB', 'Paraíba', 'Nordeste'),
    (26, 'PE', 'Pernambuco', 'Nordeste'),
    (27, 'AL', 'Alagoas', 'Nordeste'),
    (28, 'SE', 'Sergipe', 'Nordeste'),
    (29, 'BA', 'Bahia', 'Nordeste'),
    (31, 'MG', 'Minas Gerais', 'Sudeste'),
    (32, 'ES', 'Espírito Santo', 'Sudeste'),
    (33, 'RJ', 'Rio de Janeiro', 'Sudeste'),
    (35, 'SP', 'São Paulo', 'Sudeste'),
    (41, 'PR', 'Paraná', 'Sul'),
    (42, 'SC', 'Santa Catarina', 'Sul'),
    (43, 'RS', 'Rio Grande do Sul', 'Sul'),
    (50, 'MS', 'Mato Grosso do Sul', 'Centro-Oeste'),
    (51, 'MT', 'Mato Grosso', 'Centro-Oeste'),
    (52, 'GO', 'Goiás', 'Centro-Oeste'),
    (53, 'DF', 'Distrito Federal', 'Centro-Oeste')
ON CONFLICT (codigo_uf) DO UPDATE
SET sigla = EXCLUDED.sigla,
    nome = EXCLUDED.nome,
    regiao = EXCLUDED.regiao;

INSERT INTO core.dim_sexo (codigo, descricao) VALUES
    ('M', 'Masculino'),
    ('F', 'Feminino'),
    ('I', 'Ignorado')
ON CONFLICT (codigo) DO UPDATE SET descricao = EXCLUDED.descricao;

INSERT INTO core.dim_gestante (codigo, descricao) VALUES
    (1, '1º trimestre'),
    (2, '2º trimestre'),
    (3, '3º trimestre'),
    (4, 'Idade gestacional ignorada'),
    (5, 'Não'),
    (6, 'Não se aplica'),
    (9, 'Ignorado')
ON CONFLICT (codigo) DO UPDATE SET descricao = EXCLUDED.descricao;

INSERT INTO core.dim_raca (codigo, descricao) VALUES
    (1, 'Branca'),
    (2, 'Preta'),
    (3, 'Amarela'),
    (4, 'Parda'),
    (5, 'Indígena'),
    (9, 'Ignorado')
ON CONFLICT (codigo) DO UPDATE SET descricao = EXCLUDED.descricao;

INSERT INTO core.dim_escolaridade (codigo, descricao, ordem) VALUES
    (0, 'Analfabeto', 0),
    (1, '1ª a 4ª série incompleta do ensino fundamental', 1),
    (2, '4ª série completa do ensino fundamental', 2),
    (3, '5ª a 8ª série incompleta do ensino fundamental', 3),
    (4, 'Ensino fundamental completo', 4),
    (5, 'Ensino médio incompleto', 5),
    (6, 'Ensino médio completo', 6),
    (7, 'Educação superior incompleta', 7),
    (8, 'Educação superior completa', 8),
    (9, 'Ignorado', 99),
    (10, 'Não se aplica', 100)
ON CONFLICT (codigo) DO UPDATE
SET descricao = EXCLUDED.descricao,
    ordem = EXCLUDED.ordem;

INSERT INTO core.dim_classificacao_final (codigo, descricao, usar_como_confirmado) VALUES
    (0, 'Descartado', FALSE),
    (1, 'Confirmado', TRUE),
    (2, 'Em investigação', FALSE),
    (8, 'Inconclusivo', FALSE)
ON CONFLICT (codigo) DO UPDATE
SET descricao = EXCLUDED.descricao,
    usar_como_confirmado = EXCLUDED.usar_como_confirmado;

INSERT INTO core.dim_criterio (codigo, descricao) VALUES
    (0, 'Em investigação'),
    (1, 'Laboratorial'),
    (2, 'Clínico-epidemiológico')
ON CONFLICT (codigo) DO UPDATE SET descricao = EXCLUDED.descricao;

INSERT INTO core.dim_autoctonia (codigo, descricao) VALUES
    (1, 'Sim, autóctone'),
    (2, 'Não, importado'),
    (3, 'Indeterminado')
ON CONFLICT (codigo) DO UPDATE SET descricao = EXCLUDED.descricao;

INSERT INTO core.dim_doenca_trabalho (codigo, descricao) VALUES
    (0, 'Não informado'),
    (1, 'Sim'),
    (2, 'Não'),
    (9, 'Ignorado')
ON CONFLICT (codigo) DO UPDATE SET descricao = EXCLUDED.descricao;

INSERT INTO core.dim_evolucao (codigo, descricao, indica_obito) VALUES
    (0, 'Em investigação', FALSE),
    (1, 'Cura', FALSE),
    (2, 'Óbito pelo agravo', TRUE),
    (3, 'Óbito por outra causa', TRUE),
    (9, 'Ignorado', FALSE)
ON CONFLICT (codigo) DO UPDATE
SET descricao = EXCLUDED.descricao,
    indica_obito = EXCLUDED.indica_obito;

COMMIT;
