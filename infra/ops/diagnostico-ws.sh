#!/usr/bin/env bash
# Diagnostico do terminal/chat "reconectando": limite de conexoes, patch do proxy e erros do WS.
F=/ai/codall/src/terminal-ws.js
echo "== patch x-forwarded-proto presente? =="
grep -c "x-forwarded-proto" $F
echo "== limite e contagem de conexoes no codigo =="
grep -n -i -e "MAX" -e "active" -e "close(" $F | cut -c1-130 | head -15
echo "== conexoes TCP abertas na porta 3000 =="
ss -tn state established '( sport = :3000 )' 2>/dev/null | tail -n +2 | wc -l
echo "== erros/avisos recentes do terminal (log) =="
grep -h -i -e "terminal" -e "ws" -e "upgrade" -e "origin" /root/.pm2/logs/codall-out.log /root/.pm2/logs/codall-error.log 2>/dev/null | tail -15 | cut -c1-160
echo "== sessao tmux =="
tmux ls 2>&1 | head -3
echo "== uptime do codall no pm2 =="
pm2 jlist 2>/dev/null | python3 -c "import sys,json,time;[print(p['name'],p['pm2_env']['status'],'restarts',p['pm2_env']['restart_time'],'min',int((time.time()*1000-p['pm2_env']['pm_uptime'])/60000)) for p in json.load(sys.stdin)]"
