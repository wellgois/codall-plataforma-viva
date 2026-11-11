#!/usr/bin/env bash
# Entrega ao vigia o erro da geracao de prova de hoje (14:50-15:30 UTC) para ele diagnosticar e preparar a correcao.
set -euo pipefail
cd /opt/plataforma-viva/operacao/vigia
docker logs ap_backend --since 2026-11-11T14:45:00 --until 2026-11-11T15:35:00 > /tmp/apia-janela.log 2>&1 || true
python3 - <<'P'
import hashlib, time
import comum as c, coletor as k
c.garantir_pastas()
linhas = open("/tmp/apia-janela.log", errors="replace").read().splitlines()
ev = k.eventos(linhas)
if not ev:
    raise SystemExit("nenhum erro na janela")
b = ev[0]; sig = hashlib.sha1(("ap_backend|" + k.assinatura(b[0])).encode()).hexdigest()[:10]
inc = {"id": time.strftime("%Y%m%d-%H%M%S", time.gmtime()) + "-" + sig[:6], "fonte": "ap_backend", "criado": c.agora(),
       "assinatura": sig, "trecho": c.mascarar("\n".join(b))[:3500], "suprimidos_recentes": 0}
c.gravar_json(c.ENTRADA / (inc["id"] + ".json"), inc)
print("incidente entregue ao vigia:", inc["id"], "(", len(ev), "ocorrencias na janela )")
P
