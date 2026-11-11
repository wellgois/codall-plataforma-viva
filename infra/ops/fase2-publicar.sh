#!/usr/bin/env bash
# Publica no site do Codall: vitrine, pagina de confiabilidade, status.json e dbt docs.
set -euo pipefail
P=/ai/codall/public
R=/opt/plataforma-viva
mkdir -p $P/plataforma
cp $R/vitrine/index.html $P/vitrine.html
cp $R/vitrine/confiabilidade.html $P/confiabilidade.html
cd $R/infra
if [ "${1:-}" = docs ]; then
  docker compose exec -T airflow-scheduler bash -c "cd /opt/transformacao && dbt docs generate --static --profiles-dir . --target-path /tmp/docs --log-path /tmp/l >/dev/null 2>&1"
  mkdir -p $P/plataforma/dbt-docs
  docker compose cp airflow-scheduler:/tmp/docs/static_index.html $P/plataforma/dbt-docs/index.html
  echo docs publicadas
fi
