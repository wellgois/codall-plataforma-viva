# 0006 - Escopo real da stack: o que foi construido e o que ficou de fora

Data: 2026-11-11. Status: aceita; **parcialmente substituida pelo [ADR 0008](0008-spark-conferido-contra-dbt.md)** (PySpark, ver abaixo). Delta Lake e OpenLineage seguem fora do escopo.

## Contexto
O plano inicial (ADR 0001) citava Spark, Delta Lake e OpenLineage/Marquez. Ao construir, os dados reais mostraram outra escala: dezenas de milhares de linhas agregadas, em uma VPS de 2 CPUs e 8 GB compartilhada com outros produtos.

## O que existe
Airflow, Postgres, RustFS (API S3), Redpanda (API Kafka), DuckDB, dbt (dbt-duckdb) sobre arquivos Parquet, contratos de dados em YAML, monitor com alerta, linhagem publicada pelo dbt docs, Terraform (AWS) e Power BI.

## O que NAO existe (e por que)
- **PySpark (atualizado pelo ADR 0008):** na data deste ADR nao existia; depois foi adicionado so em modo local, como prova de equivalencia contra o dbt, sem substituir o DuckDB. Motivo original: para este volume, DuckDB resolve em segundos e usa uma fracao da memoria; Spark seria custo sem ganho. Continua sendo a escolha certa se o volume crescer ordens de grandeza.
- **Delta Lake:** o ganho (transacoes e time travel) nao compensa a complexidade aqui; as particoes Parquet por dia sao reescritas de forma idempotente.
- **OpenLineage/Marquez:** a linhagem publica vem do dbt docs (grafo estatico dos modelos). Nao ha captura de linhagem em tempo de execucao.

## Consequencias
- O README, a landing e o roadmap passam a descrever so o que roda.
- Spark, Delta e OpenLineage ficam como evolucao possivel, nao como promessa.
- A vitrine nao deve usar Delta Lake e OpenLineage como habilidade comprovada. Spark so conta como o que o ADR 0008 prova: job local conferido contra o dbt.
