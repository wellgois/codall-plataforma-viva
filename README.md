# Codall - Plataforma Viva em Dados

[![ci](https://github.com/wellgois/codall-plataforma-viva/actions/workflows/ci.yml/badge.svg)](https://github.com/wellgois/codall-plataforma-viva/actions/workflows/ci.yml)
[![quickstart](https://github.com/wellgois/codall-plataforma-viva/actions/workflows/quickstart.yml/badge.svg)](https://github.com/wellgois/codall-plataforma-viva/actions/workflows/quickstart.yml)

*English: [README.en.md](README.en.md)*

Uma plataforma de dados pequena, barata e **em operacao de verdade**: um lakehouse alimentado todos os dias por produtos que estao no ar, orquestrado com Airflow, transformado com dbt, com eventos em Redpanda, contratos de dados, monitor publico e um radar do mercado de dados brasileiro.

**Veja ao vivo:** [landing](https://codall.site) · [radar do mercado](https://codall.site/radar.html) · [confiabilidade](https://codall.site/confiabilidade.html) · [curriculo verificavel](https://codall.site/curriculo.html) · [demo em video](docs/media/demo.mp4)

## Rode em 15 minutos

Precisa so de Docker (Compose v2) e ~4 GB livres. Os dados sao sinteticos; nada de producao sai do autor.

```bash
git clone https://github.com/wellgois/codall-plataforma-viva
cd codall-plataforma-viva
./quickstart.sh
```

O script gera segredos aleatorios, sobe Postgres, S3 (RustFS) e Airflow, cria 30 dias de dados sinteticos, dispara a DAG (validar contratos, depois dbt build) e imprime o radar. O tempo em maquina limpa e medido a cada mudanca no [workflow quickstart](.github/workflows/quickstart.yml). Para desligar: `cd infra && docker compose down -v`.

## Arquitetura

```mermaid
flowchart LR
  P[Produtos no ar] -->|lote diario, somente leitura| E[Extratores]
  P -->|eventos| R[Redpanda]
  R --> C[Consumidor idempotente]
  E --> L[(landing: Parquet)]
  C --> L
  L --> V[Validacao de contratos]
  V --> D[dbt + DuckDB: bronze, silver, gold]
  D --> W[Radar, confiabilidade, CSV e Parquet para BI]
  A[Airflow] -. orquestra .-> V
  M[Monitor a cada 5 min] -. status.json .-> W
```

## Stack (somente o que roda)

| Camada | Ferramenta |
| --- | --- |
| Orquestracao | Apache Airflow 2.10 (DAG diaria e DAG de stream a cada 2 min) |
| Streaming | Redpanda (API Kafka), consumidor em micro-lotes |
| Armazenamento | Parquet em disco e RustFS (API S3) |
| Transformacao e consulta | dbt + DuckDB (bronze, silver, gold) |
| Qualidade | testes do dbt, contratos de dados em YAML, auditoria de privacidade |
| Confiabilidade | monitor com alerta no Telegram, postmortems, falha injetada |
| Linhagem | dbt docs publicado (grafo dos modelos) |
| Nuvem e BI | Terraform (S3, Glue, Athena, Budgets) e Power BI |
| CI | GitHub Actions: segredos, higiene, privacidade, Terraform, quickstart |

Spark, Delta Lake e OpenLineage foram considerados e **nao** foram construidos: [ADR 0006](docs/decisoes/0006-escopo-real-da-stack.md).

## O que ja foi provado

| Fase | Teste de aceite | Resultado |
| --- | --- | --- |
| 1. Lakehouse | 3 execucoes diarias seguidas sem intervencao | rodando; aceite previsto para 13/11 |
| 2. Confiabilidade | falha injetada detectada e alertada | detectada e recuperada em ciclo de 5 min (11/11) |
| 3. Streaming | evento chega ao gold em ate 2 min; reprocessar nao duplica | 72 s; reenvio e reprocesso mantiveram 1 linha |
| 4. Vitrine | nenhum dado pessoal exposto | auditoria automatica no CI e antes de publicar |
| 5. Nuvem e BI | criar e destruir e reproduzivel | 2 ciclos de 9 recursos em AWS simulada; Athena e Budgets so validados |
| 6. Lancamento | clonar e subir em maquina limpa em menos de 15 min | 98 s no GitHub Actions (11/11); workflow quickstart repete a cada mudanca |

Detalhes e limites em [docs/ROADMAP.md](docs/ROADMAP.md) e nas [decisoes](docs/decisoes).

## Privacidade

Este repositorio nunca contem dado pessoal nem segredo. Dados de alunos e de pagamentos nao saem da origem: so agregados ou anonimizados sao publicados, com k-anonimato (grupos com menos de 5 vagas sao suprimidos) e uma auditoria que bloqueia a publicacao se achar e-mail, telefone, valor, link de vaga ou campo fora da lista. Os exemplos do repositorio sao sinteticos.

## Estrutura

`ingestao/` extratores, produtor/consumidor e validador · `transformacao/` dbt · `orquestracao/` DAGs · `contratos/` contratos de dados · `confiabilidade/` monitor e auditoria · `nuvem/` e `infra/terraform/` AWS · `powerbi/` consultas e medidas · `vitrine/` paginas publicas · `docs/` roadmap, decisoes, postmortems e custos.

## Autor

Wellington Gois - Engenheiro de Dados - [LinkedIn](https://linkedin.com/in/wellingtongois)

Licenca MIT.
