#!/usr/bin/env bash
# Sobe o limite de conexoes simultaneas do terminal (5 -> 15) e reinicia o Codall.
set -e
F=/ai/codall/src/terminal-ws.js
cp "$F" "$F.bak-$(date +%Y%m%d%H%M%S)"
sed -i 's/^const MAX = 5;/const MAX = 15;/' "$F"
grep -n "^const MAX" "$F"
node --check "$F" && pm2 restart codall >/dev/null && echo "codall reiniciado"
