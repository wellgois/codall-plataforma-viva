#!/usr/bin/env bash
# Parte 2 do diagnostico do login: expiracao das sessoes, ultimos eventos de login e cabecalhos do nginx.
# Nao imprime e-mails, ips, ids de sessao nem cookies.
cd /ai/codall
echo "== minutos restantes por sessao =="
sqlite3 -readonly data/session-store.db "select (expire - strftime('%s','now')*1000)/60000 from sess_store"
echo "== eventos de login (acao e hora UTC) =="
sqlite3 -readonly data/codall.db "select created_at, action from governance_log where action like 'log%' order by id desc limit 12"
echo "== nginx do codall.site: cabecalhos repassados =="
grep -n -e proxy_set_header -e proxy_cookie -e add_header /etc/nginx/sites-available/codall.site | cut -c1-120
echo "== login: onde a sessao e gravada =="
F=$(grep -rln "authenticated = true" src server.js 2>/dev/null | head -1); echo "$F"
grep -n -B4 -A14 "authenticated = true" "$F" | grep -v -i -e password -e senha -e secret | cut -c1-150 | head -40
