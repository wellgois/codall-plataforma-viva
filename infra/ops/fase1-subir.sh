#!/usr/bin/env bash
# Gera segredos (sem imprimi-los), constroi a imagem e sobe MinIO + Postgres + Airflow.
set -euo pipefail
cd /opt/plataforma-viva/infra
if [ ! -f .env ]; then
  g() { python3 -c "import secrets;print(secrets.token_urlsafe(24))"; }
  umask 077
  cat > .env <<ENV
AIRFLOW_DB_PASSWORD=$(g)
AIRFLOW_FERNET_KEY=$(python3 -c "import base64,os;print(base64.urlsafe_b64encode(os.urandom(32)).decode())")
AIRFLOW_WEBSERVER_SECRET=$(g)
AIRFLOW_ADMIN_PASSWORD=$(g)
MINIO_ROOT_USER=pv_admin
MINIO_ROOT_PASSWORD=$(g)
LANDING_HOST_DIR=/opt/plataforma-viva/landing
ENV
  echo ".env criado (0600)"
fi
chown -R 50000:0 ../landing 2>/dev/null || true
docker compose build 2>&1 | tail -3
docker compose up -d postgres minio
docker compose up airflow-init 2>&1 | tail -4
docker compose up -d airflow-webserver airflow-scheduler
sleep 25
docker compose ps --format "table {{.Name}}\t{{.Status}}"
free -m | head -2
