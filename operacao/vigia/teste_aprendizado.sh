#!/usr/bin/env bash
# Testa o medidor com um livro sintetico: semanas, tendencia, intervalo e reincidencia.
set -euo pipefail
cd "$(dirname "$0")"
T=$(mktemp -d); export ERROS_DIR=$T VIGIA_TELEGRAM_DRY=1
python3 - <<'P'
import json, os, random, time
random.seed(1)
t0 = time.time() - 6 * 7 * 86400
ev = []
for sem in range(6):
    for i in range(8):
        auto = random.random() < 0.35 + 0.1 * sem
        rec = random.random() < 0.5 - 0.06 * sem
        ev.append({"tipo": "incidente", "ts": t0 + sem * 7 * 86400 + i * 3600, "ia": True, "reiniciou_ok": False,
                   "acao": "proposta" if auto else "nenhuma", "reincidente": rec,
                   "licao_reutilizada": rec and auto, "assinatura": f"s{sem}{i}"})
open(os.environ["ERROS_DIR"] + "/aprendizado.jsonl", "w").write("\n".join(json.dumps(e) for e in ev) + "\n")
P
python3 aprendizado.py | tee $T/saida.txt
grep -q "Semana 6" $T/saida.txt
grep -q "recorrencia: " $T/saida.txt
grep -q "autonomia: " $T/saida.txt
python3 aprendizado.py --json | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['total']['incidentes']==48"
# com poucos dados, nao pode prever
echo '{"tipo":"incidente","ts":1,"ia":true,"acao":"nenhuma"}' > $T/aprendizado.jsonl
python3 aprendizado.py | grep -q "insuficientes"
echo "TESTE DO APRENDIZADO: PASSOU"
