#!/usr/bin/env bash
# Instala o vigia de erros: pastas, coletor (cron, a cada minuto) e vigia (pm2). Pode rodar de novo sem duplicar.
set -euo pipefail
R=/opt/plataforma-viva/operacao/vigia
mkdir -p /opt/erros/{entrada,processados,relatorios,propostas}
cd "$R" && ./teste_local.sh | tail -1
pm2 describe erros-vigia >/dev/null 2>&1 && pm2 restart erros-vigia || pm2 start "$R/vigia.py" --name erros-vigia --interpreter python3 --cwd "$R"
pm2 save >/dev/null
L="* * * * * cd $R && python3 coletor.py >> /opt/erros/coletor.log 2>&1"
(crontab -l 2>/dev/null | grep -vF "operacao/vigia/coletor.py"; echo "$L") | crontab -
echo "$L"
