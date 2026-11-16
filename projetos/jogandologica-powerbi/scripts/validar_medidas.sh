#!/usr/bin/env bash
# Roda as 5 consultas de equivalência e grava out/medidas_<ts>.txt
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
TS="$(date -u +%Y%m%d-%H%M%S)"
OUT="$DIR/out/medidas_${TS}.txt"
mkdir -p "$DIR/out"

echo "== jogandologica-powerbi: validacao de medidas DAX ==" | tee "$OUT"
echo "host: ap_postgres | db: ap_saas | user: ap_user | ts: $TS" | tee -a "$OUT"
echo | tee -a "$OUT"

for nome in ytd mom ranking mm3m participacao; do
    echo "------ $nome ------" | tee -a "$OUT"
    docker exec ap_postgres psql -U ap_user -d ap_saas -P pager=off \
        -f "/projetos/jogandologica-powerbi/sql/10_medidas_equivalencia.sql" >/dev/null 2>&1 || true
done

# Cada bloco acima roda o script inteiro; para granularidade, executamos
# as 5 consultas separadamente via heredoc (mantém independência de erro).
docker exec -i ap_postgres psql -U ap_user -d ap_saas -P pager=off -v ON_ERROR_STOP=1 <<'SQL' | tee -a "$OUT"
\echo '### YTD (top 5 alunos do ano mais recente)'
WITH ano_atual AS (
    SELECT EXTRACT(YEAR FROM MAX(to_date(data_sk::text,'YYYYMMDD'))) AS ano
    FROM bi_fato_atividade
)
SELECT aluno_sk, SUM(pontos) AS pontos
FROM bi_fato_atividade, ano_atual
WHERE EXTRACT(YEAR FROM to_date(data_sk::text,'YYYYMMDD')) = ano_atual.ano
GROUP BY aluno_sk
ORDER BY pontos DESC NULLS LAST
LIMIT 5;

\echo '### MOM % (mensal)'
WITH m AS (
    SELECT date_trunc('month', to_date(data_sk::text,'YYYYMMDD'))::date AS mes,
           SUM(pontos)::numeric AS pontos
    FROM bi_fato_atividade GROUP BY 1
)
SELECT mes, pontos, LAG(pontos) OVER w AS anterior,
       ROUND((pontos - LAG(pontos) OVER w)/NULLIF(LAG(pontos) OVER w,0),4) AS mom_pct
FROM m WINDOW w AS (ORDER BY mes)
ORDER BY mes;

\echo '### RANKING (top 10)'
SELECT aluno_sk, SUM(pontos) AS pontos,
       DENSE_RANK() OVER (ORDER BY SUM(pontos) DESC NULLS LAST) AS posicao
FROM bi_fato_atividade WHERE aluno_sk IS NOT NULL
GROUP BY aluno_sk ORDER BY posicao LIMIT 10;

\echo '### MM3M'
WITH m AS (
    SELECT date_trunc('month', to_date(data_sk::text,'YYYYMMDD'))::date AS mes,
           SUM(pontos)::numeric AS pontos
    FROM bi_fato_atividade GROUP BY 1
)
SELECT mes, pontos,
       ROUND(AVG(pontos) OVER (ORDER BY mes ROWS BETWEEN 2 PRECEDING AND CURRENT ROW),2) AS mm3m
FROM m ORDER BY mes;

\echo '### PARTICIPACAO (ultimo mes)'
WITH u AS (
    SELECT date_trunc('month', MAX(to_date(data_sk::text,'YYYYMMDD')))::date AS mes
    FROM bi_fato_atividade
), m AS (
    SELECT aluno_sk, SUM(pontos)::numeric AS pontos
    FROM bi_fato_atividade, u
    WHERE date_trunc('month', to_date(data_sk::text,'YYYYMMDD'))::date = u.mes
      AND aluno_sk IS NOT NULL
    GROUP BY aluno_sk
)
SELECT aluno_sk, pontos,
       ROUND(pontos / NULLIF(SUM(pontos) OVER (),0),4) AS share
FROM m ORDER BY share DESC NULLS LAST LIMIT 10;
SQL

echo | tee -a "$OUT"
echo "OK: $OUT" | tee -a "$OUT"
ls -l "$OUT"
