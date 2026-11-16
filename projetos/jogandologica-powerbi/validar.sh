#!/usr/bin/env bash
# Validação estática da pasta do projeto (sem dados pessoais, sem out/).
set -euo pipefail
cd "$(dirname "$0")"

fail=0
ok()   { echo "OK   $1"; }
bad()  { echo "FAIL $1"; fail=$((fail+1)); }

# 1) arquivos obrigatórios
for f in README.md dax/05_medidas_core.dax sql/10_medidas_equivalencia.sql scripts/validar_medidas.sh; do
    [ -f "$f" ] && ok "existe: $f" || bad "falta: $f"
done

# 2) 5 medidas no DAX
for m in "Pontos YTD" "Pontos MoM %" "Ranking Aluno" "Pontos MM3M" "Participação %"; do
    if grep -qF "$m" dax/05_medidas_core.dax; then ok "DAX contém: $m"; else bad "DAX sem: $m"; fi
done

# 3) nenhum .csv/.xlsx versionado
if find . -type f \( -name '*.csv' -o -name '*.xlsx' \) | grep -q .; then
    bad "encontrado .csv/.xlsx (não deve ir pro git)"
else
    ok "sem .csv/.xlsx na pasta"
fi

# 4) bash -n nos scripts
for s in scripts/validar_medidas.sh validar.sh; do
    if bash -n "$s"; then ok "bash -n $s"; else bad "bash -n $s"; fi
done

echo "-----"
[ "$fail" -eq 0 ] && echo "TODOS OS CHECKS OK" || { echo "FALHAS: $fail"; exit 1; }
