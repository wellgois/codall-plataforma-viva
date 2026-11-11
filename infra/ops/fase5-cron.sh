#!/usr/bin/env bash
# Instala (idempotente) a publicacao diaria dos CSV do gold para o Power BI: 05:45.
set -euo pipefail
LINHA='45 5 * * * bash /opt/plataforma-viva/infra/ops/fase5-publicar-gold.sh >> /var/log/plataforma-viva-gold.log 2>&1'
( crontab -l 2>/dev/null | grep -v fase5-publicar-gold.sh; echo "$LINHA" ) | crontab -
crontab -l | grep fase5-publicar-gold.sh | cut -c1-60
