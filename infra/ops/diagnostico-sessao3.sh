#!/usr/bin/env bash
# Parte 3: sequencia real de requisicoes de login (sem IP) e limite de conexoes do terminal.
echo "== ultimas requisicoes do site (hora, metodo, caminho, status) =="
L=/var/log/nginx/access.log
for f in /var/log/nginx/codall.site.access.log /var/log/nginx/access.log; do [ -f "$f" ] && L=$f && break; done
grep -h -i -e "codall" "$L" 2>/dev/null | tail -400 >/dev/null
tail -300 "$L" | awk '{ t=$4; gsub(/\[/,"",t); m=$6; gsub(/"/,"",m); p=$7; sub(/\?.*/,"",p); print t, m, p, $9 }' \
  | grep -v -e "\.js " -e "\.css " -e "\.png " -e "\.ico " -e "/vendor/" -e "/plataforma/status.json" | tail -40
echo "== terminal: controle de conexoes =="
grep -n -e "active" /ai/codall/src/terminal-ws.js | cut -c1-120
echo "== erros recentes do Codall =="
tail -8 /root/.pm2/logs/codall-error.log | cut -c1-150
