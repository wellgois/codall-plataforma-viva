#!/usr/bin/env bash
# Fase 4: exporta o radar (gold -> JSON), audita privacidade e so entao publica paginas e JSON.
set -euo pipefail
R=/opt/plataforma-viva
P=/ai/codall/public
T=$(mktemp -d)
cd $R/infra
docker compose exec -T airflow-scheduler python /opt/ingestao/exportar_radar.py /opt/warehouse/plataforma.duckdb > $T/radar.json
cp $R/vitrine/radar.html $R/vitrine/curriculo.html $R/vitrine/index.html $T/
python3 $R/confiabilidade/auditoria_privacidade.py $T || { echo "PUBLICACAO BLOQUEADA"; exit 1; }
mkdir -p $P/plataforma
cp $T/radar.json $P/plataforma/radar.json
cp $R/vitrine/img/perfil.jpg $P/perfil.jpg
mkdir -p $P/vitrine-img && cp $R/vitrine/img/bi-codall.jpg $R/vitrine/img/governanca-codall.jpg $P/vitrine-img/
cp $T/radar.html $P/radar.html
cp $T/curriculo.html $P/curriculo.html
cp $T/index.html $P/vitrine.html
rm -rf $T
echo "publicado: $(python3 -c "import json;d=json.load(open('$P/plataforma/radar.json'));print(d['vagas_analisadas'],'vagas,',len(d['tecnologias']),'tecnologias')")"
