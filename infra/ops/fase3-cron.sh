#!/usr/bin/env bash
# Instala (idempotente) o produtor no host: a cada minuto publica novas linhas de governance_log.
set -euo pipefail
LINHA='* * * * * cd /opt/plataforma-viva && .venv/bin/python ingestao/stream_produtor.py --db /ai/codall/data/codall.db --estado /opt/plataforma-viva/.stream-estado >> /var/log/plataforma-viva-stream.log 2>&1'
( crontab -l 2>/dev/null | grep -v stream_produtor.py; echo "$LINHA" ) | crontab -
crontab -l | grep stream_produtor.py | cut -c1-60
