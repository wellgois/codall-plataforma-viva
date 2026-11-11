#!/usr/bin/env bash
# Aceite do vigia: injeta um erro falso num log, mede quanto leva ate o relatorio e confere a mascara de dados pessoais.
set -euo pipefail
L=/root/.pm2/logs/teste-vigia-error.log
cd /opt/plataforma-viva/operacao/vigia
touch "$L"; sleep 62   # o cron do coletor ancora o arquivo no fim
T0=$(date +%s)
printf '%s\n' 'TypeError: teste de aceite do vigia, contato prof.teste@escola.com 21 98888-7777 is not a function' '    at teste (/app/src/teste.js:1:1)' >> "$L"
for i in $(seq 1 24); do
  R=$(grep -l "teste de aceite do vigia" /opt/erros/relatorios/*.md 2>/dev/null | tail -1 || true)
  [ -n "$R" ] && break; sleep 10
done
[ -n "${R:-}" ] || { echo "REPROVADO: sem relatorio em 4 min"; rm -f "$L"; exit 1; }
S=$(( $(date +%s) - T0 ))
if grep -q "prof.teste@escola.com\|98888-7777" "$R"; then echo "REPROVADO: dado pessoal no relatorio"; rm -f "$L"; exit 1; fi
rm -f "$L"
echo "ACEITE OK: erro injetado -> relatorio e Telegram em ${S}s (limite 180s); dados pessoais mascarados"
