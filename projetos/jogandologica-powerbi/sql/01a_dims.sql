CREATE OR REPLACE VIEW bi_dim_escola AS
SELECT DISTINCT btrim(escola) AS escola FROM dever_missoes WHERE escola IS NOT NULL AND btrim(escola)<>''
UNION SELECT DISTINCT btrim(escola) FROM logika_missoes WHERE escola IS NOT NULL AND btrim(escola)<>'';

CREATE OR REPLACE VIEW bi_dim_disciplina AS
SELECT DISTINCT COALESCE(disciplina,'(n/d)') AS disciplina FROM dever_missoes;

CREATE OR REPLACE VIEW bi_dim_jogo AS
SELECT DISTINCT jogo_id AS jogo FROM jogos_educativos_sessoes WHERE jogo_id IS NOT NULL;

CREATE OR REPLACE VIEW bi_dim_aluno AS
WITH base AS (
  SELECT aluno_id::text AS aluno_id, aluno_nome, escola, turma FROM dever_missoes
  UNION ALL
  SELECT aluno_id::text, NULL::text, NULL::text, NULL::text FROM jogos_educativos_sessoes
  UNION ALL
  SELECT 'eq:'||substr(md5(equipe_nome),1,12), equipe_nome, escola, turma FROM logika_missoes WHERE equipe_nome IS NOT NULL
)
SELECT COALESCE(NULLIF(aluno_id,''), 'n:'||substr(md5(aluno_nome),1,12)) AS aluno_sk,
       max(aluno_id) AS aluno_id, 'Aluno '||substr(md5(max(COALESCE(NULLIF(aluno_id,''), aluno_nome))),1,6) AS aluno_nome,
       max(btrim(escola)) AS escola, max(turma) AS turma
FROM base GROUP BY COALESCE(NULLIF(aluno_id,''), 'n:'||substr(md5(aluno_nome),1,12));

CREATE OR REPLACE VIEW bi_dim_data AS
WITH e AS (SELECT min(coalesce(iniciado_em,created_at))::date AS d0 FROM dever_missoes),
     f AS (SELECT max(coalesce(iniciado_em,created_at))::date AS d1 FROM dever_missoes)
SELECT to_char(d,'YYYYMMDD')::int AS data_sk, d AS data,
       EXTRACT(YEAR FROM d)::int AS ano, EXTRACT(MONTH FROM d)::int AS mes,
       EXTRACT(DAY FROM d)::int AS dia, to_char(d,'Mon') AS mes_nome,
       EXTRACT(ISODOW FROM d)::int AS dia_semana,
       date_trunc('week',d)::date AS inicio_semana, date_trunc('month',d)::date AS inicio_mes
FROM generate_series((SELECT d0 FROM e),(SELECT d1 FROM f),'1 day') AS d;
