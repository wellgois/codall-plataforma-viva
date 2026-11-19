-- extract_snapshot.sql
-- Extrai o modelo estrela SEM PII (sem aluno_nome, sem escola_nome).
-- Uso:
--   docker exec -i ap_postgres psql -U ap_user -d ap_saas -A -F',' -f - \
--     < sql/extract_snapshot.sql > out/snapshot.csv

COPY (
  SELECT
    f.data_sk,
    f.aluno_sk,
    f.jogo_sk,
    f.disciplina,
    f.tipo_atividade,
    f.status,
    f.pontos,
    f.acertos,
    f.erros,
    f.tentativas,
    f.segundos
  FROM bi_fato_atividade f
  ORDER BY f.data_sk
) TO STDOUT WITH CSV HEADER;
EOF
