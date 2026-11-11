# Postmortem: MinIO sem imagem publica durante a subida da Fase 1

Data: 11/11/2026. Severidade: baixa (bloqueio de deploy, sem impacto em producao).
Formato sem culpados.

## Resumo
`docker compose up` falhou ao baixar `minio/minio`. A tentativa seguinte, no espelho
`quay.io/minio/minio`, tambem falhou com `unauthorized`.

## Causa raiz
O projeto MinIO Community Edition foi arquivado e as imagens oficiais foram removidas do Docker Hub
e do Quay. O plano de 10/11 assumia a imagem como disponivel.

## Deteccao
Imediata, no primeiro pull. Uma busca confirmou que nao era falha local.

## Decisao
Trocar por RustFS (S3-compativel, Apache 2.0). Registrado em
[ADR 0002](../decisoes/0002-armazenamento-s3.md). O pipeline fala apenas S3, entao a troca
custou um bloco do compose.

## Aprendizado
Dependencias de infraestrutura tambem tem prazo de validade. Conferir a disponibilidade da
imagem no planejamento, nao no deploy.
