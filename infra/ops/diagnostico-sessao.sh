#!/usr/bin/env bash
# Diagnostico do loop de login do Codall. Nao imprime ids de sessao, cookies nem segredos.
cd /ai/codall
echo "== processo =="; pm2 describe codall | grep -e restarts -e uptime -e status | cut -c1-80
echo "== reinicios recentes (log) =="; grep -c "Server running" /root/.pm2/logs/codall-out.log
echo "== relogio =="; date -u +%s; date -u
echo "== store de sessao: esquema =="; sqlite3 -readonly data/session-store.db .schema | cut -c1-200
echo "== linhas / expiracao (min, max) =="
for t in $(sqlite3 -readonly data/session-store.db "select name from sqlite_master where type='table'"); do
  echo "tabela $t: $(sqlite3 -readonly data/session-store.db "select count(*) from $t")"
done
sqlite3 -readonly data/session-store.db "select count(*), min(expired), max(expired) from sessions" 2>/dev/null || sqlite3 -readonly data/session-store.db "select count(*), min(expire), max(expire) from sessions" 2>/dev/null
echo "== implementacao do store =="; grep -rn -l SqliteStore server.js src | head -3
F=$(grep -rln "class SqliteStore" server.js src 2>/dev/null | head -1); [ -n "$F" ] && grep -n -A40 "class SqliteStore" "$F" | grep -i -e expire -e maxAge -e ttl -e DELETE -e cleanup -e interval | cut -c1-170
echo "== cookie / proxy =="; grep -n -e "trust proxy" -e "rolling" -e "maxAge" server.js | cut -c1-140
