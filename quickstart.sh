#!/usr/bin/env bash
# Sobe a plataforma do zero em uma maquina limpa, com dados SINTETICOS, e prova que funciona:
# gera dados -> valida contratos -> dbt (bronze, silver, gold) -> mostra o radar.
# Requisitos: Docker com Compose v2 e ~4 GB livres de memoria. Nao precisa de Python no host.
set -euo pipefail
cd "$(dirname "$0")"
T0=$(date +%s)
log() { echo "[$(( $(date +%s) - T0 ))s] $*"; }

command -v docker >/dev/null || { echo "Docker nao encontrado"; exit 1; }
docker compose version >/dev/null || { echo "Docker Compose v2 nao encontrado"; exit 1; }

mkdir -p landing && chmod a+rwx landing
cd infra
if [ ! -f .env ]; then
  g() { head -c 24 /dev/urandom | base64 | tr -d '=+/\n'; }
  umask 077
  cat > .env <<ENV
AIRFLOW_DB_PASSWORD=$(g)
AIRFLOW_FERNET_KEY=$(head -c 32 /dev/urandom | base64 | tr '+/' '-_' | tr -d '\n')
AIRFLOW_WEBSERVER_SECRET=$(g)
AIRFLOW_ADMIN_PASSWORD=$(g)
S3_ACCESS_KEY=pv_admin
S3_SECRET_KEY=$(g)
LANDING_HOST_DIR=$(cd .. && pwd)/landing
ENV
  log ".env criado com segredos aleatorios (infra/.env, fora do git)"
fi

log "construindo a imagem do Airflow"
docker compose build airflow-init >/dev/null
log "subindo Postgres e S3 (RustFS)"
docker compose up -d postgres s3 >/dev/null
log "inicializando o Airflow"
docker compose up airflow-init >/dev/null 2>&1
docker compose up -d airflow-webserver airflow-scheduler >/dev/null

log "aguardando o scheduler"
for i in $(seq 1 60); do
  docker compose exec -T airflow-scheduler airflow version >/dev/null 2>&1 && break
  sleep 5
done
docker compose exec -T -u root airflow-scheduler chown -R airflow /opt/warehouse

log "gerando 30 dias de dados sinteticos no landing"
docker compose exec -T airflow-scheduler python /opt/ingestao/sintetico.py /opt/landing --dias 30 >/dev/null

log "aguardando a DAG ser lida"
for i in $(seq 1 60); do
  docker compose exec -T airflow-scheduler airflow dags list 2>/dev/null | grep -q plataforma_viva_diaria && break
  sleep 5
done
docker compose exec -T airflow-scheduler airflow dags unpause plataforma_viva_diaria >/dev/null 2>&1
docker compose exec -T airflow-scheduler airflow dags trigger plataforma_viva_diaria >/dev/null 2>&1
log "DAG disparada; aguardando o resultado (validar contratos -> dbt build)"
ESTADO=""
for i in $(seq 1 60); do
  SAIDA=$(docker compose exec -T airflow-scheduler airflow dags list-runs -d plataforma_viva_diaria -o json 2>/dev/null || true)
  if echo "$SAIDA" | grep -q '"state": "success"'; then ESTADO=success; break; fi
  if echo "$SAIDA" | grep -q '"state": "failed"'; then ESTADO=failed; break; fi
  sleep 10
done
if [ "$ESTADO" != "success" ]; then
  log "FALHOU (estado: ${ESTADO:-tempo esgotado})"
  docker compose logs --tail=40 airflow-scheduler
  exit 1
fi

log "DAG concluida com sucesso. Radar de demanda (dados sinteticos), ultimo dia:"
docker compose exec -T airflow-scheduler python - <<'PY'
import duckdb
c = duckdb.connect('/opt/warehouse/plataforma.duckdb', read_only=True)
for t, p in c.execute("select tecnologia, pct_vagas from gold_radar_demanda where dt=(select max(dt) from gold_radar_demanda) order by pct_vagas desc limit 5").fetchall():
    print(f"  {t:<12} {p:>5.1f}% das vagas")
PY
log "PRONTO. Airflow: http://127.0.0.1:8088 (usuario admin; a senha esta em infra/.env)"
log "Para desligar e limpar: (cd infra && docker compose down -v)"
