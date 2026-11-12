#!/usr/bin/env bash
# Teste do vigia sem VPS: log falso, codigo falso e IA simulada. Verifica coletor, dedupe, mascara, proposta e aplicacao.
set -euo pipefail
cd "$(dirname "$0")"
T=$(mktemp -d); export ERROS_DIR=$T/erros VIGIA_SEM_DOCKER=1 VIGIA_TELEGRAM_DRY=1 VIGIA_FONTES=$T/fontes.json VIGIA_LLM_STUB=$T/llm.json
mkdir -p $T/logs $T/src
cat > $T/src/test.ts <<'X'
const total = 1;
const g = (data.gabarito || questoes).map((q) => q.resposta);
X
python3 - "$T" <<'P'
import json,sys
t=sys.argv[1]
json.dump({"pm2_logs":t+"/logs","ignorar_pm2":[],"containers":{},"pm2_apps":{"appteste":{"nome":"App de teste","codigo":t+"/src","deploy":"true","reiniciar":"true"}},
 "limites":{"novos_por_rodada":5,"novos_por_hora":12,"reinicios_por_hora":2,"repetir_apos_horas":6}},open(t+"/fontes.json","w"))
json.dump([{"resumo":"A prova nao foi gerada.","causa_provavel":"O gabarito veio num formato inesperado.","gravidade":"alta","tipo":"codigo","termo_busca":"(data.gabarito || questoes).map","acao_segura":"nenhuma"},
 {"arquivo":t+"/src/test.ts","antes":"(data.gabarito || questoes).map((q) => q.resposta)","depois":"(Array.isArray(data.gabarito) ? data.gabarito : questoes).map((q) => q.resposta)","explicacao":"Usa o gabarito so se for lista."}],open(t+"/llm.json","w"))
P
touch $T/logs/appteste-error.log
python3 coletor.py                                   # 1a vez: ancora no fim do arquivo
printf '%s\n' '{"level":"error","message":"Job 439 falhou: (data.gabarito || questoes).map is not a function","user":"prof@escola.com","tel":"21 98888-7777"}' >> $T/logs/appteste-error.log
python3 coletor.py                                   # detecta 1 incidente
printf '%s\n' '{"level":"error","message":"Job 440 falhou: (data.gabarito || questoes).map is not a function"}' >> $T/logs/appteste-error.log
python3 coletor.py | tee $T/saida3.txt               # repetido: nao cria outro
grep -q "0 incidente" $T/saida3.txt
[ "$(ls $T/erros/entrada | wc -l)" = 1 ]
! grep -rq "prof@escola.com\|98888-7777" $T/erros/entrada
python3 vigia.py --uma-vez | tee $T/saida4.txt
grep -q "tratados: 1" $T/saida4.txt
ls $T/erros/relatorios/*.md >/dev/null
ID=$(basename $(ls $T/erros/propostas/*.json) .json)
python3 aplicar.py "$ID" | tee $T/saida5.txt
grep -q "Array.isArray" $T/src/test.ts
ls $T/src/test.ts.bak-vigia-* >/dev/null
# reincidencia: o mesmo erro volta; a licao e reaproveitada (sem 2a chamada da IA) e o livro registra
cp $T/src/test.ts.bak-vigia-* $T/src/test.ts
python3 -c "import json,sys;p=sys.argv[1]+'/erros/estado.json';d=json.load(open(p));d['assinaturas']={};json.dump(d,open(p,'w'))" $T
python3 - "$T" <<'P'
import json,sys
json.dump([{"resumo":"Voltou.","causa_provavel":"Mesmo gabarito.","gravidade":"alta","tipo":"codigo","termo_busca":"x","acao_segura":"nenhuma"}],open(sys.argv[1]+"/llm.json","w"))
P
printf '%s\n' '{"level":"error","message":"Job 441 falhou: (data.gabarito || questoes).map is not a function"}' >> $T/logs/appteste-error.log
python3 coletor.py | grep -q "1 incidente"
python3 vigia.py --uma-vez | grep -q "tratados: 1"
grep -q "reaproveitada\|ATENCAO" $T/erros/relatorios/*.md
python3 aprendizado.py | grep -q "Acumulado: 2 incidentes"
echo "TESTE DO VIGIA: PASSOU"
