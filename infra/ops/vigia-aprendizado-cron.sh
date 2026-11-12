#!/usr/bin/env bash
# Relatorio semanal de aprendizado do Codall no Telegram (segunda, 08:00 de Brasilia = 11:00 UTC). Reexecutavel.
set -euo pipefail
R=/opt/plataforma-viva/operacao/vigia
cd "$R" && ./teste_aprendizado.sh | tail -1
L="0 11 * * 1 cd $R && python3 aprendizado.py --telegram >> /opt/erros/aprendizado.log 2>&1"
(crontab -l 2>/dev/null | grep -vF "aprendizado.py"; echo "$L") | crontab -
echo "$L"
python3 aprendizado.py | head -3
