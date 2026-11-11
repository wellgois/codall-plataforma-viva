# 0001 - Escolha da stack

Data: 10/11/2026. Status: aceita.

## Contexto

A plataforma roda em uma unica VPS (2 CPUs, 8 GB de memoria) junto com os produtos que ela observa. A escolha de ferramentas seguiu a demanda medida em 26 vagas brasileiras de Engenharia de Dados coletadas em novembro/2026: SQL (26), Python (24), CI/CD (22), Spark (21), governanca (21), qualidade (19), lakehouse (15), Databricks (14), Airflow (13), AWS (13), Kafka (10), dbt (9).

## Decisao

- Airflow para orquestracao (LocalExecutor, por causa da memoria).
- Redpanda no lugar do Kafka: mesma API, sem JVM, cabe na VPS.
- RustFS + Delta Lake: API S3 local, com espelho opcional em AWS S3.
- PySpark apenas em lote e fora do horario de uso; DuckDB para consultas baratas.
- dbt para modelagem, testes e documentacao.

## Consequencias

- Com 2 CPUs, roda um job Spark por vez.
- Tudo sobe com Docker Compose; a nuvem e opcional e tem teto de gasto.
