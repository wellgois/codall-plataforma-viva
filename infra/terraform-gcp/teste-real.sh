#!/usr/bin/env bash
# Ciclo criar -> publicar -> consultar -> destruir no BigQuery sandbox, duas vezes.
# Uso: bash teste-real.sh <pasta_parquet>   (GOOGLE_APPLICATION_CREDENTIALS e TF_VAR_project_id no ambiente)
set -euo pipefail
cd "$(dirname "$0")"
PASTA="$1"
terraform init -input=false >/dev/null
falhas=0
for ciclo in 1 2; do
  terraform apply -auto-approve -input=false >/dev/null
  if python ../../nuvem/publicar_gcp.py "$PASTA" --projeto "$TF_VAR_project_id" --dataset plataforma_viva; then
    echo "ciclo $ciclo: publicado e conferido"
  else
    echo "ciclo $ciclo: FALHA na publicacao"; falhas=$((falhas + 1))
  fi
  terraform destroy -auto-approve -input=false >/dev/null
  echo "ciclo $ciclo: destruido"
done
echo "falhas: $falhas"
exit "$falhas"
