#!/usr/bin/env bash
# Publica a landing page do repositorio no site do Codall (arquivo estatico, sem restart).
set -euo pipefail
D=/ai/codall/public/vitrine.html
cp -a "$D" "/root/backups/vitrine.html.bak-$(date +%Y%m%dT%H%M%S)"
cp /opt/plataforma-viva/vitrine/index.html "$D"
mkdir -p /ai/codall/public/vitrine-img && cp /opt/plataforma-viva/vitrine/img/bi-codall.jpg /opt/plataforma-viva/vitrine/img/governanca-codall.jpg /ai/codall/public/vitrine-img/
grep -c "no ar" "$D"
