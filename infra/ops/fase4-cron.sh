#!/usr/bin/env bash
# Instala (idempotente) a publicacao diaria do radar: 05:40, depois da DAG das 05:00.
set -euo pipefail
LINHA='40 5 * * * bash /opt/plataforma-viva/infra/ops/fase4-publicar.sh >> /var/log/plataforma-viva-radar.log 2>&1'
( crontab -l 2>/dev/null | grep -v fase4-publicar.sh; echo "$LINHA" ) | crontab -
crontab -l | grep fase4-publicar.sh | cut -c1-60
