# Codall - Plataforma Viva em Dados

Uma plataforma de dados pequena, barata e **em operacao de verdade**: um lakehouse alimentado todos os dias por cinco produtos que estao no ar, orquestrado com Airflow e operado por um agente de IA (Codall) sob auditoria.

> Status: **Fase 0 - base** (iniciado em 10/11/2026). Este README descreve o que existe hoje e o que esta planejado. Nada aqui e marcado como pronto antes de passar no teste de aceite.

## Por que este projeto existe

A maioria dos portfolios de engenharia de dados usa datasets prontos. Aqui os dados vem de produtos reais, com usuarios reais: falhas reais, dado sujo real, custo real e LGPD real. O objetivo e mostrar o dia 2 de uma plataforma: agendamento, backfill, qualidade, linhagem, incidentes e custo.

## Arquitetura (alvo)

```
Fontes (5 produtos no ar)
        |
        v
Ingestao: lote diario (extractors) + eventos (Redpanda, API Kafka)
        |
        v
Lakehouse: bronze -> silver -> gold   (RustFS/S3 + Delta Lake, PySpark, dbt)
        |
        v
Vitrine publica: confiabilidade, catalogo e linhagem, radar do mercado de dados

Airflow orquestra | Codall opera e audita | GitHub Actions publica
```

## Stack

| Camada | Ferramenta |
| --- | --- |
| Orquestracao | Apache Airflow |
| Streaming | Redpanda (API Kafka) |
| Armazenamento | RustFS (API S3) + Delta Lake; espelho opcional em AWS S3 |
| Processamento | PySpark e DuckDB |
| Transformacao | dbt (modelo dimensional e camada semantica) |
| Qualidade | testes do dbt + contratos de dados |
| Linhagem | OpenLineage + Marquez |
| CI/CD e IaC | GitHub Actions, Docker Compose, Terraform |

## Roteiro

| Fase | Entrega | Status |
| --- | --- | --- |
| 0 | Base: capacidade medida, repositorio, CI | em andamento |
| 1 | Lakehouse com Airflow (bronze, silver, gold) | planejada |
| 2 | Confiabilidade publica: contratos, linhagem, postmortems | planejada |
| 3 | Streaming com Redpanda | no ar (aceite de 11/11) |
| 4 | Vitrine: curriculo verificavel e radar do mercado | no ar (auditoria de privacidade) |
| 5 | AWS com Terraform e teto de gasto; Power BI | pronta (teste simulado; conta real em janeiro) |
| 6 | Lancamento | planejada |

Detalhes em [docs/ROADMAP.md](docs/ROADMAP.md).

## Privacidade

Este repositorio nunca contem dado pessoal nem segredo. Dados de alunos e de pagamentos nao saem da origem: a plataforma publica apenas agregados ou dados anonimizados, e os exemplos do repositorio sao sinteticos.

## Autor

Wellington Gois - Engenheiro de Dados - [LinkedIn](https://linkedin.com/in/wellingtongois)

Licenca MIT.
