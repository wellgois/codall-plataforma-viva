#!/usr/bin/env bash
# Instala os agendamentos da Fase 2 no cron do host (monitor a cada 5 min; docs do dbt as 05:20).
set -euo pipefail
P=/ai/codall/public
R=/opt/plataforma-viva
cat > /tmp/.cron-fase2 <<CRON
*/5 * * * * cd $R && .venv/bin/python confiabilidade/monitor.py --landing landing --contratos contratos --saida $P/plataforma --estado $R/estado-monitor.json --alerta $R/.alerta --compose-dir $R/infra >> /var/log/plataforma-viva-monitor.log 2>&1
20 5 * * * bash $R/infra/ops/fase2-publicar.sh docs >> /var/log/plataforma-viva-docs.log 2>&1
CRON
( crontab -l 2>/dev/null | grep -v -e confiabilidade/monitor.py -e fase2-publicar.sh; cat /tmp/.cron-fase2 ) | crontab -
rm /tmp/.cron-fase2
crontab -l | grep -c -e monitor.py -e fase2-publicar
