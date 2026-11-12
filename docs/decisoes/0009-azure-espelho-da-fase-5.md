# 0009 - Azure: mesmo desenho da Fase 5, validado sem conta

Data: 2026-11-11. Status: aceita (validada tambem na conta real em 12/11).

## Decisao
`infra/terraform-azure` espelha o modulo AWS: grupo de recursos, conta de armazenamento Data Lake Gen2 (LRS, TLS 1.2, sem acesso publico), container `lake`, politica de limpeza de 7 dias, identidade para o publicador com papel de dados de blob (sem gerenciar a assinatura) e orcamento com alertas em 50/80/100%. `nuvem/publicar_azure.py` envia o gold ao container.

## Como foi testado sem conta
- CI: `terraform fmt`, `init` e `validate` do modulo Azure.
- CI e local: Azurite (emulador oficial de armazenamento) em 2 ciclos de criar container, publicar o gold, conferir nome e tamanho dos arquivos e destruir. 0 falhas.

## Limites conhecidos
- Nao existe emulador gratuito do gerenciamento da Azure (ARM). Grupo, conta, papel e orcamento ficam cobertos so por `validate`; o primeiro `plan`/`apply` na conta real e o teste final deles.
- Consulta SQL serverless (Synapse) ficou de fora: o Power BI e o DuckDB leem o Parquet direto do armazenamento, sem custo fixo.
- Orcamento alerta, nao bloqueia gasto.

## Atualizacao de 12/11 (assinatura Azure real)
- `plan`: 8 recursos. `apply`: 8 criados sem erro, incluindo orcamento e atribuicao de papel, antes so validados.
- Ciclo destroy -> apply repetido 2 vezes: 8 destruidos e 8 criados em cada ciclo, 0 falhas.
- O login interativo (`az login`) da VPS foi bloqueado pelos security defaults do diretorio (AADSTS530035). Foi usada uma identidade so para o Terraform (service principal) criada no portal; o segredo vive so no arquivo protegido da VPS e a identidade e removida ao fim do teste.
- Fora desta rodada: publicar o gold no armazenamento Azure com identidade de dados (o caminho foi provado no Azurite).
