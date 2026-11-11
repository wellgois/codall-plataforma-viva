# Roteiro

Cada fase so fecha quando o teste de aceite passa.

| Fase | Entrega | Teste de aceite |
| --- | --- | --- |
| 0. Base | Capacidade da VPS medida; repositorio publico; CI | CI verde; varredura de segredos = 0 |
| 1. Lakehouse com Airflow | RustFS e Delta; extractors (agregado ou anonimizado); dbt bronze/silver/gold; DAG diario | 3 execucoes diarias seguidas sem intervencao; backfill de 30 dias; testes do dbt verdes |
| 2. Confiabilidade publica | Contratos de dados, linhagem, pagina de confiabilidade, postmortems | Falha injetada detectada e alertada em ate 15 min |
| 3. Streaming | Redpanda recebendo eventos; consumidor gravando no bronze | Evento de teste chega ao gold em ate 2 min; reprocessar nao duplica |
| 4. Vitrine | Curriculo verificavel e radar do mercado de dados | Nenhum dado pessoal exposto |
| 5. Nuvem e BI | Terraform para AWS com teto de gasto; Power BI sobre a camada gold | Criar e destruir a infraestrutura e reproduzivel |
| 6. Lancamento | README PT/EN, video curto | Clonar e subir em maquina limpa em menos de 15 min |
