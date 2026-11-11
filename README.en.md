# Codall - Living Data Platform

[![ci](https://github.com/wellgois/codall-plataforma-viva/actions/workflows/ci.yml/badge.svg)](https://github.com/wellgois/codall-plataforma-viva/actions/workflows/ci.yml)
[![quickstart](https://github.com/wellgois/codall-plataforma-viva/actions/workflows/quickstart.yml/badge.svg)](https://github.com/wellgois/codall-plataforma-viva/actions/workflows/quickstart.yml)

*Portugues: [README.md](README.md)*

A small, cheap data platform that **runs for real**: a lakehouse fed daily by live products, orchestrated with Airflow, transformed with dbt, with Redpanda events, data contracts, a public monitor and a radar of the Brazilian data job market. Pages and docs are in Portuguese; the code and this README are bilingual.

**Live:** [landing](https://codall.site) · [market radar](https://codall.site/radar.html) · [reliability](https://codall.site/confiabilidade.html) · [verifiable resume](https://codall.site/curriculo.html) · [demo video](docs/media/demo.mp4)

## Run it in 15 minutes

You only need Docker (Compose v2) and ~4 GB of free memory. Data is synthetic; nothing from production leaves the author.

```bash
git clone https://github.com/wellgois/codall-plataforma-viva
cd codall-plataforma-viva
./quickstart.sh
```

The script generates random secrets, starts Postgres, S3 (RustFS) and Airflow, creates 30 days of synthetic data, triggers the DAG (contract validation, then dbt build) and prints the radar. Time on a clean machine is measured on every change by the [quickstart workflow](.github/workflows/quickstart.yml). To tear down: `cd infra && docker compose down -v`.

## Architecture

```mermaid
flowchart LR
  P[Live products] -->|daily batch, read-only| E[Extractors]
  P -->|events| R[Redpanda]
  R --> C[Idempotent consumer]
  E --> L[(landing: Parquet)]
  C --> L
  L --> V[Contract validation]
  V --> D[dbt + DuckDB: bronze, silver, gold]
  D --> W[Radar, reliability page, CSV and Parquet for BI]
  A[Airflow] -. orchestrates .-> V
  M[Monitor every 5 min] -. status.json .-> W
```

## Stack (only what runs)

| Layer | Tool |
| --- | --- |
| Orchestration | Apache Airflow 2.10 (daily DAG and a 2-minute stream DAG) |
| Streaming | Redpanda (Kafka API), micro-batch consumer |
| Storage | Parquet on disk and RustFS (S3 API) |
| Transformation and query | dbt + DuckDB (bronze, silver, gold) |
| Quality | dbt tests, YAML data contracts, privacy audit |
| Reliability | monitor with Telegram alerts, postmortems, injected failure test |
| Lineage | published dbt docs (model graph) |
| Cloud and BI | Terraform (S3, Glue, Athena, Budgets) and Power BI |
| CI | GitHub Actions: secrets, hygiene, privacy, Terraform, quickstart |

Spark, Delta Lake and OpenLineage were considered and were **not** built: [ADR 0006](docs/decisoes/0006-escopo-real-da-stack.md).

## What has been proven

| Phase | Acceptance test | Result |
| --- | --- | --- |
| 1. Lakehouse | 3 consecutive daily runs without intervention | running; acceptance expected on Nov 13 |
| 2. Reliability | injected failure detected and alerted | detected and recovered within a 5-minute cycle (Nov 11) |
| 3. Streaming | event reaches gold within 2 min; replay does not duplicate | 72 s; resend and replay kept 1 row |
| 4. Showcase | no personal data exposed | automatic audit in CI and before publishing |
| 5. Cloud and BI | create and destroy is reproducible | 2 cycles of 9 resources on simulated AWS; Athena and Budgets only validated |
| 6. Launch | clone and run on a clean machine in under 15 min | measured by the quickstart workflow |

## Privacy

This repository never contains personal data or secrets. Student and payment data never leave their source: only aggregates or anonymised data are published, with k-anonymity (groups under 5 jobs are suppressed) and an audit that blocks publishing if it finds an e-mail, phone, amount, job link or unexpected field. Repository examples are synthetic.

## Author

Wellington Gois - Data Engineer - [LinkedIn](https://linkedin.com/in/wellingtongois)

MIT License.
