# Roteiro

Cada fase so fecha quando o teste de aceite passa.

| Fase | Entrega | Teste de aceite |
| --- | --- | --- |
| 0. Base | Capacidade da VPS medida; repositorio publico; CI | CI verde; varredura de segredos = 0 |
| 1. Lakehouse com Airflow | RustFS e Parquet; extractors (agregado ou anonimizado); dbt bronze/silver/gold; DAG diario | 3 execucoes diarias seguidas sem intervencao; backfill de 30 dias; testes do dbt verdes |
| 2. Confiabilidade publica | Contratos de dados, linhagem, pagina de confiabilidade, postmortems | Falha injetada detectada e alertada em ate 15 min (teste de 11/11: detectada e recuperada em ciclos de 5 min; alerta no Telegram pendente de token) |
| 3. Streaming | Redpanda recebendo eventos; consumidor gravando no bronze | Evento de teste chega ao gold em ate 2 min; reprocessar nao duplica (teste de 11/11: 72 s; reenvio e reprocesso do topico mantiveram 1 linha) |
| 4. Vitrine | Curriculo verificavel e radar do mercado de dados | Nenhum dado pessoal exposto (auditoria automatica nas paginas e no JSON; teste negativo reprova e-mail, valor, link de vaga e campo fora da lista) |
| 5. Nuvem e BI | Terraform para AWS com teto de gasto; Power BI sobre a camada gold | Criar e destruir a infraestrutura e reproduzivel (teste de 11/11 em AWS simulada: 2 ciclos de 9 recursos, 0 falhas; Athena e Budgets so validados, ver ADR 0005) |
| 6. Lancamento | README PT/EN, video curto | Clonar e subir em maquina limpa em menos de 15 min (teste de 11/11 no GitHub Actions: 98 s, ver workflow quickstart) |
| 7. Spark | Job PySpark (modo local) que refaz uma tabela gold a partir do silver, com Delta Lake opcional | Resultado identico ao do dbt (diferenca = 0 linhas), dentro do limite de memoria da VPS e rodando no CI (teste de 11/11: 404 linhas nos dois, diferenca = 0, pico ~111 MB; ver ADR 0008) |
| 8. Azure (candidata) | Espelhar o Terraform da Fase 5 em Azure (armazenamento + consulta serverless) com teto de gasto | Criar e destruir reproduzivel em Azure simulado; so depois da conta real de nuvem (teste de 11/11: modulo valida no CI; caminho dos dados em 2 ciclos no Azurite, 0 falhas; recursos de gerenciamento so validados, ver ADR 0009) |
