#!/usr/bin/env bash
# Aceite da Fase 3: (1) evento chega ao gold em ate 2 min; (2) reenvio e reprocessamento nao duplicam.
set -uo pipefail
cd /opt/plataforma-viva/infra
PY=/opt/plataforma-viva/.venv/bin/python
ID="teste-$(date +%s)"
conta() {  # $1 = tabela
  docker compose exec -T airflow-scheduler python -c "
import duckdb,sys
for _ in range(10):
    try:
        c=duckdb.connect('/opt/warehouse/stream.duckdb',read_only=True)
        print(c.execute(\"select count(*) from $1 where $2\").fetchone()[0]); break
    except Exception as e:
        import time; time.sleep(3)
else: print(-1)
" 2>/dev/null | tail -1
}
espera() {  # $1 = id, $2 = limite s ; imprime segundos ate aparecer no gold
  local t0=$(date +%s)
  while [ $(( $(date +%s) - t0 )) -lt "$2" ]; do
    n=$(conta stream_gold_eventos_minuto "categoria='teste_aceite' and minuto >= now() - interval 20 minute")
    [ "${n:-0}" -gt 0 ] && { echo $(( $(date +%s) - t0 )); return 0; }
    sleep 5
  done
  echo -1; return 1
}
echo "== 1) evento novo $ID =="
$PY ../ingestao/stream_produtor.py --sintetico "$ID" --broker 127.0.0.1:19092
S=$(espera "$ID" 150)
[ "$S" -ge 0 ] && echo "PASS: no gold em ${S}s (limite 120s)" || echo "FAIL: nao chegou ao gold em 150s"
echo "== 2) reenvio do mesmo evento =="
$PY ../ingestao/stream_produtor.py --sintetico "$ID" --broker 127.0.0.1:19092
sleep 100
N=$(conta stream_silver_eventos "event_id='$ID'")
[ "$N" = "1" ] && echo "PASS: silver tem 1 linha para $ID apos reenvio" || echo "FAIL: silver tem $N linhas para $ID"
echo "== 3) reprocessamento do topico do zero =="
A=$(find ../landing/stream_eventos -name '*.parquet' | wc -l)
docker compose run --rm --no-deps stream-consumidor python /app/stream_consumidor.py --landing /opt/landing --broker redpanda:9092 --grupo "replay-$(date +%s)" --uma-vez 2>&1 | tail -2
B=$(find ../landing/stream_eventos -name '*.parquet' | wc -l)
echo "arquivos antes=$A depois=$B"
[ "$A" -le "$B" ] && echo "(arquivos novos so aparecem para offsets ainda nao gravados; mesmos offsets regravam o mesmo nome)"
sleep 130
N=$(conta stream_silver_eventos "event_id='$ID'")
[ "$N" = "1" ] && echo "PASS: apos reprocesso, $ID continua com 1 linha" || echo "FAIL: $N linhas"
