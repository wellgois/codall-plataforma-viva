#!/usr/bin/env bash
# Instala (de forma idempotente) a extracao diaria no host: 04:30, antes da DAG das 05:00.
set -euo pipefail
LINHA='30 4 * * * cd /opt/plataforma-viva && .venv/bin/python ingestao/extrair_codall.py --db /ai/codall/data/codall.db --landing landing --salt-file /opt/plataforma-viva/.salt --dias 2 >> /var/log/plataforma-viva-extracao.log 2>&1'
( crontab -l 2>/dev/null | grep -v extrair_codall.py; echo "$LINHA" ) | crontab -
crontab -l | grep extrair_codall.py | cut -c1-60
