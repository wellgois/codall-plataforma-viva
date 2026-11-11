#!/usr/bin/env bash
# Corrige o 401 do WebSocket do terminal do Codall: o cookie de sessao e secure e o
# upgrade chega ao Node sem o contexto HTTPS. Marca a requisicao como vinda do proxy TLS
# (o nginx ja termina o TLS e a origem e validada pela lista ALLOWED).
set -euo pipefail
F=/ai/codall/src/terminal-ws.js
cp -a "$F" "$F.bak-$(date +%Y%m%dT%H%M%S)"
python3 - "$F" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
marca = "req.headers['x-forwarded-proto'] = 'https';"
if marca in s:
    print('ja aplicado'); sys.exit(0)
alvo = "if (!req.url.startsWith('/ws/terminal')) return socket.destroy();"
assert alvo in s, 'trecho nao encontrado'
open(p, 'w').write(s.replace(alvo, alvo + "\n    " + marca, 1))
print('patch aplicado')
PY
node --check "$F" && echo sintaxe ok
echo --- store de sessao ---
grep -n -B1 -A6 _sessionStore /ai/codall/server.js | head -30
echo --- reiniciando codall ---
pm2 restart codall >/dev/null && sleep 3 && pm2 ls | grep codall
