# 0007. Vigia de erros com correcao assistida

Data: 11/11/2026. Motivo: a geracao de uma prova no APIA falhou por 30 minutos (job 439, `(data.gabarito || questoes).map is not a function`) e so foi descoberta porque a professora avisou.

## O que foi feito
- **Coletor** (cron, 1 min): junta erros novos dos logs do pm2 e de containers Docker, mascara e-mail, telefone, CPF e segredos, agrupa repeticoes e grava um arquivo por incidente em `/opt/erros/entrada`. Limites: 5 novos por rodada, 12 por hora.
- **Vigia** (pm2): le a pasta, pede diagnostico a uma IA (DeepSeek, so com texto ja mascarado), grava relatorio em `/opt/erros/relatorios` e envia no Telegram.
- **Acao automatica** so para reinicio de app travado (maximo 2 por hora por app).
- **Defeito de codigo**: o vigia localiza o trecho, propoe uma troca minima e a guarda em `/opt/erros/propostas`. `aplicar.py` faz backup, aplica, reconstroi e reverte sozinho se falhar.

## Decisoes e limites
- Correcao de codigo em producao **nao** e aplicada sem aprovacao humana; a primeira correcao real (APIA, 11/11) passou por revisao do diff.
- A correcao evita o erro, mas nao descobre por que a IA do APIA devolveu o gabarito em formato inesperado.
- A chave da IA fica em `/opt/erros/chave_llm` (permissao 600), fora do repositorio.
- O vigia ignora o proprio log para nao se denunciar.

## Teste
`operacao/vigia/teste_local.sh` (log falso, IA simulada) e `infra/ops/vigia-aceite.sh` (erro injetado na VPS, tempo ate o relatorio).

## Resultado (11/11/2026)
- Caso real: o erro da prova do APIA foi diagnosticado pelo vigia e a correcao aplicada com backup (relatorio e mensagem no Telegram).
- Aceite com erro injetado: relatorio e Telegram dentro do limite de 180 s, com e-mail e telefone mascarados (`infra/ops/vigia-aceite.sh`: ACEITE OK).
