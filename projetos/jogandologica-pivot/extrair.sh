#!/usr/bin/env bash
# Extrai dados AGREGADOS/anonimizados de jogos_educativos e sessoes.
# Anonimizacao: aluno_ref sequencial (A0001...) por DENSE_RANK em aluno_id.
# Nunca sai do banco: name, school, class_name, titulo, tenant_id, professor_id.
# Saida fora da pasta publicada: /root/dados-jogandologica/*.csv (chmod 600).
set -euo pipefail

PRJ="$(cd "$(dirname "$0")" && pwd)"
DAT="${DAT:-/root/dados-jogandologica}"
mkdir -p "$DAT"; chmod 700 "$DAT"

PSQL=(docker exec ap_postgres psql -U ap_user -d ap_saas -v ON_ERROR_STOP=1 -tA -F,)

echo "[1/3] sessoes_anon.csv"
"${PSQL[@]}" -c "
COPY (
  WITH map AS (
    SELECT aluno_id,
           'A' || lpad(DENSE_RANK() OVER (ORDER BY aluno_id)::text,4,'0') AS aluno_ref
    FROM (SELECT DISTINCT aluno_id FROM jogos_educativos_sessoes WHERE aluno_id IS NOT NULL
          UNION SELECT DISTINCT aluno_id FROM jogos_educativos WHERE aluno_id IS NOT NULL) x
  )
  SELECT s.id,
         s.jogo_id,
         COALESCE(m.aluno_ref,'A0000')          AS aluno_ref,
         COALESCE(s.pontuacao,0)                AS pontuacao,
         COALESCE(s.acertos,0)                  AS acertos,
         COALESCE(s.erros,0)                    AS erros,
         COALESCE(s.tempo_gasto_segundos,0)     AS tempo_seg,
         COALESCE(s.status,'desconhecido')      AS status,
         to_char(s.iniciado_em,'YYYY-MM-DD HH24:MI:SS') AS iniciado,
         COALESCE(to_char(s.finalizado_em,'YYYY-MM-DD HH24:MI:SS'),'') AS finalizado
  FROM jogos_educativos_sessoes s
  LEFT JOIN map m ON m.aluno_id = s.aluno_id
  ORDER BY s.iniciado_em
) TO STDOUT CSV HEADER" > "$DAT/sessoes_anon.csv"

echo "[2/3] jogos_anon.csv"
"${PSQL[@]}" -c "
COPY (
  SELECT j.id,
         j.tipo,
         j.nivel,
         COALESCE(j.tamanho,'')           AS tamanho,
         COALESCE(j.tempo_minutos,0)      AS tempo_min,
         COALESCE(j.pontos_max,0)         AS pontos_max,
         COALESCE(j.status,'desconhecido') AS status,
         COALESCE(j.catalogo,false)       AS catalogo,
         to_char(j.created_at,'YYYY-MM-DD HH24:MI:SS') AS criado
  FROM jogos_educativos j
  ORDER BY j.created_at
) TO STDOUT CSV HEADER" > "$DAT/jogos_anon.csv"

echo "[3/3] agregado_aluno_jogo.csv"
"${PSQL[@]}" -c "
COPY (
  WITH map AS (
    SELECT aluno_id,
           'A' || lpad(DENSE_RANK() OVER (ORDER BY aluno_id)::text,4,'0') AS aluno_ref
    FROM (SELECT DISTINCT aluno_id FROM jogos_educativos_sessoes WHERE aluno_id IS NOT NULL) x
  )
  SELECT COALESCE(m.aluno_ref,'A0000') AS aluno_ref,
         s.jogo_id                     AS jogo_id,
         COUNT(*)                      AS sessoes,
         SUM(COALESCE(s.acertos,0))    AS total_acertos,
         SUM(COALESCE(s.erros,0))      AS total_erros,
         SUM(COALESCE(s.pontuacao,0))  AS total_pontos,
         ROUND(AVG(COALESCE(s.tempo_gasto_segundos,0))::numeric,1) AS tempo_medio_seg
  FROM jogos_educativos_sessoes s
  LEFT JOIN map m ON m.aluno_id = s.aluno_id
  GROUP BY 1,2
  ORDER BY 1,2
) TO STDOUT CSV HEADER" > "$DAT/agregado_aluno_jogo.csv"

chmod 600 "$DAT"/*.csv
echo "[OK] arquivos em $DAT:"
ls -l "$DAT"/*.csv
