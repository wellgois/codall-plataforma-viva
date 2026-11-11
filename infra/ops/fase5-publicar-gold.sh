#!/usr/bin/env bash
# Exporta o gold (parquet + CSV), audita e publica os CSV para o Power BI (caminho A).
# Se AWS_BUCKET estiver definido, envia tambem o Parquet ao S3 (caminho B).
set -euo pipefail
R=/opt/plataforma-viva
P=/ai/codall/public/plataforma/gold
cd $R/infra
docker compose up -d airflow-scheduler airflow-webserver >/dev/null 2>&1  # monta /opt/nuvem (idempotente)
sleep 15
docker compose exec -T airflow-scheduler bash -c "rm -rf /opt/landing/_gold_export && python /opt/nuvem/exportar_gold.py /opt/warehouse/plataforma.duckdb /opt/landing/_gold_export"
E=$R/landing/_gold_export
python3 $R/confiabilidade/auditoria_privacidade.py $E/csv || { echo "PUBLICACAO BLOQUEADA"; exit 1; }
mkdir -p $P && cp $E/csv/*.csv $P/
if [ -n "${AWS_BUCKET:-}" ]; then $R/.venv/bin/python $R/nuvem/publicar_nuvem.py $E/parquet "$AWS_BUCKET"; fi
echo "gold publicado: $(ls $P | tr '\n' ' ')"
