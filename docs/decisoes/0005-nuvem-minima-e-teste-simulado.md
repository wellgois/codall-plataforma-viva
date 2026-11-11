# 0005 - Nuvem minima com teto de gasto e teste de criar/destruir em AWS simulada

Data: 2026-11-11. Status: aceita.

## Contexto
A conta AWS so sera aberta em janeiro, com teto de R$ 30 a R$ 50 por mes. A Fase 5 pede infraestrutura reproduzivel (criar e destruir) e Power BI sobre o gold.

## Decisao
- Terraform com S3, Glue Catalog, Athena (workgroup com limite por consulta), IAM minimo e Budgets. Nada que cobre por hora.
- A chave de acesso do publicador nao e criada pelo Terraform (nao entra no estado); sai do console e vive so no ambiente da VPS.
- Power BI por dois caminhos: CSV publico auditado (funciona hoje, custo zero) e Athena via ODBC (apos a conta existir).
- O ciclo apply/destroy e testado contra uma AWS simulada (moto) na VPS, duas vezes seguidas.

## Consequencias
- Prova real de que o modulo valida e cria/destroi 9 recursos sem sobras, sem gastar nada.
- Limite conhecido: o moto nao implementa tags do Athena nem assinaturas do Budgets, entao esses dois recursos ficam desligados no teste (variaveis `habilitar_athena` e `habilitar_orcamento`) e cobertos apenas por `terraform validate`. O primeiro `plan`/`apply` na conta real e o teste final deles.
- Budgets alerta, mas nao bloqueia gasto.

## Evidencia
`infra/terraform/teste-local.sh`: fmt ok, validate ok, 2 ciclos apply (9 criados) e destroy (9 removidos), 0 falhas.

## Atualizacao de 11/11 (conta AWS real)
- `plan` na conta real: 11 recursos (os 9 do teste simulado mais o workgroup Athena e o orcamento).
- `apply`: 11 criados sem erro. Athena e Budgets, antes so validados, funcionaram na conta real.
- Gold publicado no S3 (2 arquivos Parquet) e consultado no Athena (limite de 100 MB por consulta ativo).
- Ciclo destroy -> apply repetido 2 vezes: 11 destruidos e 11 criados em cada ciclo, 0 falhas.
- A chave do usuario administrador do Terraform foi usada so neste teste e removida depois; o segredo nunca entrou no repositorio.
