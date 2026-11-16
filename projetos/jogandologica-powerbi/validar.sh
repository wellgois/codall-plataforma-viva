#!/usr/bin/env bash
set -euo pipefail
BASE="$(cd "$(dirname "$0")" && pwd)"
PSQL="docker exec -i ap_postgres psql -U ap_user -d ap_saas -v ON_ERROR_STOP=1 -P pager=off"

echo "== aplicando views (01a + 01b) =="
$PSQL < "$BASE/sql/01a_dims.sql" >/dev/null
$PSQL < "$BASE/sql/01b_fato.sql" >/dev/null

echo "== amostra =="
docker exec -i ap_postgres psql -U ap_user -d ap_saas -P pager=off < "$BASE/sql/02_amostra.sql"

echo "== contagem fato =="
docker exec ap_postgres psql -U ap_user -d ap_saas -At -c "select 'fato_total='||count(*) from bi_fato_atividade;"

echo "OK"
