#!/usr/bin/env bash
# Prepara o venv do host, roda o extrator (backfill de 30 dias) e valida os contratos.
set -euo pipefail
cd /opt/plataforma-viva
[ -d .venv ] || python3 -m venv .venv
.venv/bin/pip install -q pyarrow pyyaml
mkdir -p landing
.venv/bin/python ingestao/extrair_codall.py --db /ai/codall/data/codall.db --landing landing --salt-file /opt/plataforma-viva/.salt --dias ${1:-30}
.venv/bin/python ingestao/validar_contrato.py landing contratos
du -sh landing; ls landing/*/ | head -4
