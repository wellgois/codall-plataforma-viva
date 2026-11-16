-- =====================================================================
-- Equivalência SQL das 5 medidas DAX (validação no Postgres ap_saas)
-- Executar SOMENTE leitura. Saída usada por scripts/validar_medidas.sh
-- =====================================================================

-- 1) YTD de pontos por aluno (ano mais recente no fato)
WITH ano_atual AS (
    SELECT EXTRACT(YEAR FROM MAX(to_date(data_sk::text,'YYYYMMDD'))) AS ano
    FROM bi_fato_atividade
),
base AS (
    SELECT f.aluno_sk,
           EXTRACT(YEAR FROM to_date(f.data_sk::text,'YYYYMMDD')) AS ano,
           f.pontos
    FROM bi_fato_atividade f
)
SELECT 'ytd' AS medida, aluno_sk,
       SUM(pontos) AS valor
FROM base, ano_atual
WHERE base.ano = ano_atual.ano
GROUP BY aluno_sk
ORDER BY valor DESC NULLS LAST
LIMIT 5;

-- 2) MoM % — total mensal e variação vs mês anterior
WITH mensal AS (
    SELECT date_trunc('month', to_date(data_sk::text,'YYYYMMDD'))::date AS mes,
           SUM(pontos) AS pontos
    FROM bi_fato_atividade
    GROUP BY 1
),
lagged AS (
    SELECT mes, pontos, LAG(pontos) OVER (ORDER BY mes) AS anterior
    FROM mensal
)
SELECT 'mom' AS medida, mes,
       pontos,
       anterior,
       ROUND( (pontos - anterior)::numeric / NULLIF(anterior,0), 4) AS mom_pct
FROM lagged
ORDER BY mes;

-- 3) Ranking denso de alunos por pontos totais (top 10)
SELECT 'ranking' AS medida, aluno_sk,
       SUM(pontos) AS pontos,
       DENSE_RANK() OVER (ORDER BY SUM(pontos) DESC NULLS LAST) AS posicao
FROM bi_fato_atividade
WHERE aluno_sk IS NOT NULL
GROUP BY aluno_sk
ORDER BY posicao
LIMIT 10;

-- 4) Média móvel 3 meses do total de pontos
WITH mensal AS (
    SELECT date_trunc('month', to_date(data_sk::text,'YYYYMMDD'))::date AS mes,
           SUM(pontos)::numeric AS pontos
    FROM bi_fato_atividade
    GROUP BY 1
)
SELECT 'mm3m' AS medida, mes,
       pontos,
       ROUND(AVG(pontos) OVER (ORDER BY mes ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2) AS mm3m
FROM mensal
ORDER BY mes;

-- 5) Participação % do aluno no mês (último mês disponível)
WITH ultimo AS (
    SELECT date_trunc('month', MAX(to_date(data_sk::text,'YYYYMMDD')))::date AS mes
    FROM bi_fato_atividade
),
mensal AS (
    SELECT aluno_sk, SUM(pontos)::numeric AS pontos
    FROM bi_fato_atividade, ultimo
    WHERE date_trunc('month', to_date(data_sk::text,'YYYYMMDD'))::date = ultimo.mes
      AND aluno_sk IS NOT NULL
    GROUP BY aluno_sk
)
SELECT 'participacao' AS medida, aluno_sk,
       pontos,
       ROUND(pontos / NULLIF(SUM(pontos) OVER (),0), 4) AS share
FROM mensal
ORDER BY share DESC NULLS LAST
LIMIT 10;
