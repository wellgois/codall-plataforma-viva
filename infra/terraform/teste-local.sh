#!/usr/bin/env bash
# Teste de criar/destruir sem tocar na AWS real: aplica o modulo contra uma AWS simulada (moto) em Docker.
# Roda init, fmt, validate e dois ciclos apply -> destroy (prova de reprodutibilidade).
# O moto nao implementa tags do Athena nem assinaturas do Budgets: esses dois recursos ficam
# desligados aqui e sao cobertos por validate (e por plan na conta real).
set -uo pipefail
cd "$(dirname "$0")"
TF=hashicorp/terraform:1.9.8
NET=pv-tf-teste
W=.tmp-teste
cleanup() { docker rm -f pv-moto >/dev/null 2>&1; docker network rm $NET >/dev/null 2>&1; }
trap cleanup EXIT
cleanup; rm -rf $W; mkdir $W; cp *.tf $W/
cat > $W/override.tf <<'HCL'
provider "aws" {
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  s3_use_path_style           = true
  # o moto nao implementa tags do Athena: no teste, sem default_tags
  default_tags {
    tags = {}
  }
  endpoints {
    s3      = "http://pv-moto:5000"
    iam     = "http://pv-moto:5000"
    sts     = "http://pv-moto:5000"
    glue    = "http://pv-moto:5000"
    athena  = "http://pv-moto:5000"
    budgets = "http://pv-moto:5000"
  }
}
HCL
docker network create $NET >/dev/null
docker run -d --name pv-moto --network $NET motoserver/moto:latest >/dev/null
sleep 8
tf() { docker run --rm --network $NET -e TF_VAR_email_alerta=teste@example.com -e TF_VAR_habilitar_athena=false -e TF_VAR_habilitar_orcamento=false -v "$PWD/$W:/w" -w /w $TF "$@"; }
FALHAS=0
passo() { if "$@"; then echo "PASS: $*" | cut -c1-90; else echo "FAIL: $*" | cut -c1-90; FALHAS=$((FALHAS+1)); fi; }
passo tf init -no-color -input=false >/tmp/tf-init.log 2>&1 || tail -5 /tmp/tf-init.log
tf fmt -check -diff -no-color >/tmp/tf-fmt.log 2>&1 && echo "PASS: fmt" || { echo "FAIL: fmt (veja diff)"; head -20 /tmp/tf-fmt.log; FALHAS=$((FALHAS+1)); }
passo tf validate -no-color
for ciclo in 1 2; do
  echo "== ciclo $ciclo: apply =="
  tf apply -auto-approve -no-color -input=false >/tmp/tf-apply$ciclo.log 2>&1 && echo "PASS: apply $(grep -E '^Apply complete' /tmp/tf-apply$ciclo.log)" || { echo "FAIL: apply"; tail -15 /tmp/tf-apply$ciclo.log; FALHAS=$((FALHAS+1)); }
  echo "== ciclo $ciclo: destroy =="
  tf destroy -auto-approve -no-color -input=false >/tmp/tf-destroy$ciclo.log 2>&1 && echo "PASS: destroy $(grep -E '^Destroy complete' /tmp/tf-destroy$ciclo.log)" || { echo "FAIL: destroy"; tail -15 /tmp/tf-destroy$ciclo.log; FALHAS=$((FALHAS+1)); }
done
echo "falhas: $FALHAS"
exit $FALHAS
