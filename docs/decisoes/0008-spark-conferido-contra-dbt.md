# 0008. Spark em modo local, conferido contra o dbt

Status: aceita (Fase 7)

## Contexto
Muitas vagas pedem Spark. O projeto usava DuckDB + dbt, que resolve bem o volume atual. Faltava prova de que a mesma regra de negocio roda em Spark.

## Decisao
`spark/gold_radar_demanda.py` refaz em PySpark (modo local, 2 nucleos, driver com 512 MB) a tabela `gold_radar_demanda` a partir da mesma landing Parquet, com a mesma regra de tecnologia e a mesma media movel de 7 dias. `spark/conferir_com_dbt.py` compara as duas tabelas com EXCEPT nos dois sentidos e falha se houver qualquer diferenca. O job roda no CI (`spark`).

## Resultado
Com 30 dias de dados sinteticos: 404 linhas no dbt, 404 no Spark, 0 linhas de diferenca. Pico de memoria do processo medido no ambiente de teste: cerca de 111 MB, dentro do limite de 512 MB configurado no driver.

## Consequencias
- Spark continua sendo prova de equivalencia, nao substituto: para este volume o DuckDB e mais simples e rapido.
- Delta Lake ficou opcional e nao foi incluido nesta fase.
