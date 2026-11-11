#!/usr/bin/env bash
# Publica a landing page do repositorio no site do Codall (arquivo estatico, sem restart).
set -euo pipefail
D=/ai/codall/public/vitrine.html
cp -a "$D" "/root/backups/vitrine.html.bak-$(date +%Y%m%dT%H%M%S)"
cp /opt/plataforma-viva/vitrine/index.html "$D"
grep -c "no ar" "$D"
