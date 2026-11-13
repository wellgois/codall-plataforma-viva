# 0011 - GCP: BigQuery sandbox, sem conta de cobranca

Data: 2026-11-13. Status: aceita (validada na conta real em 13/11).

## Contexto
O radar de vagas pede GCP e o projeto nao tinha nenhuma prova. A Fase 8 mostrou o desenho em Azure; faltava um terceiro provedor sem custo e sem cartao.

## Decisao
`infra/terraform-gcp` cria um dataset no BigQuery em modo sandbox (sem conta de cobranca). `nuvem/publicar_gcp.py` carrega o Parquet do gold por job de carga e confere a contagem de linhas com a origem. `infra/terraform-gcp/teste-real.sh` repete duas vezes criar, publicar, consultar e destruir.

## Limites conhecidos
- Sandbox: tabelas expiram em 60 dias e nao ha streaming. Por isso a expiracao e declarada no Terraform.
- Sem Cloud Storage e sem orcamento: esses recursos exigem conta de cobranca. O equivalente de armazenamento em objetos ja esta provado em AWS e Azure.
- Nao ha emulador oficial do BigQuery usado no CI: o CI roda `terraform validate`; a publicacao e testada na conta real.
- A conta de servico do Terraform e usada so no teste e removida depois; a chave fica em arquivo protegido na VPS, fora do repositorio.

## Resultado de 13/11 (projeto GCP real, BigQuery sandbox)
- `teste-real.sh`: 2 ciclos de criar o dataset, carregar o gold, conferir a contagem de linhas contra o Parquet de origem e destruir. 0 falhas.
- Fora desta rodada: Cloud Storage e orcamento (exigem conta de cobranca).
