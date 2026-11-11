# 0002 - Armazenamento S3: RustFS no lugar do MinIO

Data: 11/11/2026. Status: aceita.

## Contexto
O plano original usava MinIO como armazenamento S3 local (lakehouse). Ao subir a Fase 1,
`docker pull minio/minio` falhou (`pull access denied`) e o espelho em `quay.io/minio/minio`
passou a negar pulls anonimos. O repositorio do MinIO Community Edition esta arquivado
desde abril de 2026 e deixou de publicar imagens.

## Decisao
Usar **RustFS** (Apache 2.0, API S3, console web, imagem publica) com a mesma topologia:
um container, preso a 127.0.0.1, com limite de memoria de 384 MB. Garage foi a alternativa
considerada; RustFS vence pela configuracao minima (variaveis de ambiente, sem etapa de layout).

## Consequencias
- Nenhum codigo de pipeline depende do fornecedor: tudo fala S3 (`s3://`), entao trocar de
  novo custa um bloco do compose.
- RustFS 1.0 e recente: a Fase 1 registra no diario qualquer comportamento inesperado.
- Em AWS (Fase 5) o equivalente e S3 de verdade; o contrato de acesso nao muda.
