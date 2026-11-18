-- KPIs agregados do JogandoLógica (somente leitura, sem dados pessoais).
-- Fonte: view bi_fato_atividade (ver ../jogandologica-powerbi/sql/01b_fato.sql).
-- Saída: um único documento JSON (psql -At).
WITH f AS (
  SELECT tipo_atividade, aluno_sk, jogo_sk,
         to_date(data_sk::text, 'YYYYMMDD') AS dia,
         acertos, erros, tentativas, segundos
  FROM bi_fato_atividade
  WHERE data_sk IS NOT NULL
),
resumo AS (
  SELECT count(*) AS atividades,
         count(DISTINCT aluno_sk) AS participantes,
         min(dia) AS inicio, max(dia) AS fim
  FROM f
),
mensal AS (
  SELECT to_char(date_trunc('month', dia), 'YYYY-MM') AS mes,
         tipo_atividade AS tipo,
         count(*) AS atividades,
         count(DISTINCT aluno_sk) AS participantes
  FROM f GROUP BY 1, 2
),
mensal_total AS (
  SELECT to_char(date_trunc('month', dia), 'YYYY-MM') AS mes,
         count(*) AS atividades,
         count(DISTINCT aluno_sk) AS participantes
  FROM f GROUP BY 1
),
acerto AS (
  SELECT tipo_atividade AS tipo,
         count(*) AS atividades_com_tentativa,
         round(100.0 * sum(COALESCE(acertos,0))
               / NULLIF(sum(COALESCE(acertos,0) + COALESCE(erros,0)), 0), 1) AS taxa_acerto
  FROM f WHERE COALESCE(tentativas,0) > 0 GROUP BY 1
),
jogos AS (
  SELECT jogo_sk AS jogo,
         count(*) AS sessoes,
         round((avg(segundos) FILTER (WHERE segundos BETWEEN 1 AND 3600) / 60.0)::numeric, 1) AS minutos_medios,
         round(100.0 * sum(COALESCE(acertos,0))
               / NULLIF(sum(COALESCE(acertos,0) + COALESCE(erros,0)), 0), 1) AS taxa_acerto
  FROM f WHERE tipo_atividade = 'sessao' AND jogo_sk IS NOT NULL
  GROUP BY 1 ORDER BY 2 DESC LIMIT 8
),
semana AS (
  SELECT extract(isodow FROM dia)::int AS dia_semana, count(*) AS atividades
  FROM f GROUP BY 1
)
SELECT json_build_object(
  'gerado_em', to_char(now() AT TIME ZONE 'utc', 'YYYY-MM-DD"T"HH24:MI"Z"'),
  'resumo',  (SELECT row_to_json(resumo) FROM resumo),
  'mensal',  (SELECT json_agg(row_to_json(mensal) ORDER BY mes, tipo) FROM mensal),
  'mensal_total', (SELECT json_agg(row_to_json(mensal_total) ORDER BY mes) FROM mensal_total),
  'acerto',  (SELECT json_agg(row_to_json(acerto) ORDER BY tipo) FROM acerto),
  'jogos',   (SELECT json_agg(row_to_json(jogos) ORDER BY sessoes DESC) FROM jogos),
  'semana',  (SELECT json_agg(row_to_json(semana) ORDER BY dia_semana) FROM semana)
);
