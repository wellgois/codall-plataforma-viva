#!/usr/bin/env bash
# Fase 3: sobe Redpanda + consumidor, instala o cliente Kafka no venv do host e faz um primeiro envio.
set -euo pipefail
cd /opt/plataforma-viva/infra
.././.venv/bin/pip install -q confluent-kafka "pyarrow<18"
docker compose build stream-consumidor 2>&1 | tail -2
docker compose up -d redpanda
for i in $(seq 1 30); do
  docker compose ps redpanda --format '{{.Status}}' | grep -q healthy && break; sleep 5
done
docker compose ps redpanda --format '{{.Name}} {{.Status}}'
docker compose up -d stream-consumidor
# a DAG nova e a alteracao da diaria sao lidas pelo scheduler a cada ~60 s
docker compose exec -T airflow-scheduler airflow dags unpause plataforma_viva_stream >/dev/null 2>&1 || true
docker compose ps --format "table {{.Name}}\t{{.Status}}"
free -m | head -2
