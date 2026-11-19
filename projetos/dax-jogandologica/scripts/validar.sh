#!/usr/bin/env bash
# validar.sh — confere os NÚMEROS que o Power BI deve mostrar, lendo direto do Postgres.
set -euo pipefail
docker exec ap_postgres psql -U ap_user -d ap_saas -P pager=off -c "
SELECT
   COUNT(*)                     AS total_atividades,
   COUNT(DISTINCT aluno_sk)     AS alunos,
   COUNT(DISTINCT jogo_sk)      AS jogos,
   SUM(pontos)                  AS total_pontos,
   SUM(acertos)                 AS acertos,
   SUM(tentativas)              AS tentativas,
   ROUND(SUM(acertos)::numeric / NULLIF(SUM(tentativas),0), 4) AS taxa_acerto,
   ROUND(SUM(segundos)/60.0, 2) AS minutos_totais,
   MIN(data_sk)                 AS data_min,
   MAX(data_sk)                 AS data_max
FROM bi_fato_atividade;

SELECT tipo_atividade, COUNT(*) AS qtd, SUM(pontos) AS pontos
FROM bi_fato_atividade GROUP BY 1 ORDER BY 2 DESC LIMIT 10;

SELECT status, COUNT(*) FROM bi_fato_atividade GROUP BY 1 ORDER BY 2 DESC;
"
EOF
