#!/usr/bin/env bash
# Gera dashboard/kpis.json (consulta agregada no Postgres) e dashboard/index.html
# (HTML autocontido com os dados embutidos). Somente leitura no banco.
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
docker exec -i ap_postgres psql -U ap_user -d ap_saas -At -v ON_ERROR_STOP=1 \
  < "$DIR/sql/kpis.sql" > "$DIR/dashboard/kpis.json"
python3 -I - "$DIR" <<'PY'
import json, sys, pathlib
d = pathlib.Path(sys.argv[1])
dados = json.loads((d / "dashboard/kpis.json").read_text())
tpl = (d / "dashboard/template.html").read_text()
blob = json.dumps(dados, ensure_ascii=False).replace("</", "<\\/")
(d / "dashboard/index.html").write_text(tpl.replace("__DADOS__", blob))
print("ok:", dados["resumo"])
PY
