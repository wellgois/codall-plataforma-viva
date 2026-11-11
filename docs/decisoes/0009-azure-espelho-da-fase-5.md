# 0009 - Azure: mesmo desenho da Fase 5, validado sem conta

Data: 2026-11-11. Status: aceita (conta real pendente).

## Decisao
`infra/terraform-azure` espelha o modulo AWS: grupo de recursos, conta de armazenamento Data Lake Gen2 (LRS, TLS 1.2, sem acesso publico), container `lake`, politica de limpeza de 7 dias, identidade para o publicador com papel de dados de blob (sem gerenciar a assinatura) e orcamento com alertas em 50/80/100%. `nuvem/publicar_azure.py` envia o gold ao container.

## Como foi testado sem conta
- CI: `terraform fmt`, `init` e `validate` do modulo Azure.
- CI e local: Azurite (emulador oficial de armazenamento) em 2 ciclos de criar container, publicar o gold, conferir nome e tamanho dos arquivos e destruir. 0 falhas.

## Limites conhecidos
- Nao existe emulador gratuito do gerenciamento da Azure (ARM). Grupo, conta, papel e orcamento ficam cobertos so por `validate`; o primeiro `plan`/`apply` na conta real e o teste final deles.
- Consulta SQL serverless (Synapse) ficou de fora: o Power BI e o DuckDB leem o Parquet direto do armazenamento, sem custo fixo.
- Orcamento alerta, nao bloqueia gasto.
