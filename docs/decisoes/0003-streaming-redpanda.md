# 0003 - Streaming com Redpanda, micro-lotes e deduplicacao por event_id

Data: 2026-11-11. Status: aceita.

## Contexto
A Fase 3 precisa mostrar eventos em tempo quase real sem estourar o VPS (8 GB, varios servicos).

## Decisao
- Redpanda em modo dev-container (1 core, 512 MB), API Kafka, preso a 127.0.0.1.
- Produtor no host le `governance_log` (SQLite somente leitura) por rowid e publica em `codall.eventos`; `event_id = gov-<rowid>`; o estado so avanca apos a entrega confirmada.
- Consumidor em container grava micro-lotes parquet (200 eventos ou 15 s). Nome do arquivo = particao + offsets (`lote-p0-5-7.parquet`), escrita com tmp + rename, commit do offset so depois do arquivo no lugar.
- dbt com tag `stream` em DuckDB proprio (`stream.duckdb`), DAG a cada 2 min; a DAG diaria exclui `tag:stream`.
- Silver deduplica por `event_id`.

## Consequencias
- Reprocessar o topico regrava os mesmos arquivos e reenviar o mesmo evento conta uma vez (garantia "pelo menos uma vez" + idempotencia).
- Latencia medida de ponta a ponta: 72 s (limite 120 s), dominada pelo ciclo de 2 min da DAG.
- Limite: nao e streaming de verdade (sem janela continua); suficiente para a vitrine e barato em memoria.

## Evidencia
`infra/ops/fase3-teste.sh`: PASS evento no gold em 72 s; PASS reenvio com 1 linha no silver; PASS reprocesso do zero com 1 linha.
