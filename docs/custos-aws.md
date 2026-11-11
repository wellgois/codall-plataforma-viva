# Custos e teto de gasto na AWS (Fase 5)

Principio: so servicos que cobram por uso real, nada que cobre por hora ligado.

| Recurso | Cobranca | Estimativa mensal nesta escala |
| --- | --- | --- |
| S3 (gold em Parquet, poucos MB) | por GB-mes e requisicoes | menos de US$ 0,05 |
| Glue Data Catalog (2 tabelas) | gratis ate 1 milhao de objetos | US$ 0 |
| Athena (workgroup com limite de 100 MB por consulta) | US$ 5 por TB lido | menos de US$ 0,01 |
| AWS Budgets (1 orcamento) | os 2 primeiros sao gratis | US$ 0 |
| IAM | gratis | US$ 0 |

Estimativas por tabela de precos publicada pela AWS; confira na sua conta antes de depender delas.

## O que nunca entra no modulo
EC2, RDS, NAT Gateway, MSK, EMR, Redshift e Load Balancer: cobram por hora ligados e estouram o teto sozinhos.

## Camadas de protecao
1. `bytes_scanned_cutoff_per_query` no workgroup cancela qualquer consulta acima de 100 MB.
2. Orcamento mensal de US$ 8 (variavel `teto_mensal_usd`) com e-mail em 50%, 80%, 100% do gasto real e 100% da previsao.
3. Politica IAM do publicador so escreve em `gold/`.
4. `terraform destroy` remove tudo (bucket com `force_destroy`).

O Budgets avisa, mas nao bloqueia sozinho: se o alerta de 100% chegar, rode `terraform destroy`.

## Como usar (quando a conta existir)
```
cd infra/terraform
cp terraform.tfvars.example meu.auto.tfvars   # ajuste o e-mail
terraform init && terraform plan && terraform apply
# criar uma chave de acesso do usuario *-publicador no console e exporta-la so no ambiente da VPS
```
