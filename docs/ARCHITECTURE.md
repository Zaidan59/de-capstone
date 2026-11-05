# Architecture and Trust Boundaries

```text
Windows 11 / Linux Host
  |
  +-- http://127.0.0.1:8978  CloudBeaver UI
  +-- https://127.0.0.1:3001 Webtop browser remote desktop
  |       |-- Apache Hop GUI 2.19 / CLI
  |       |-- VSCodium desktop; Python3, Java 21, Maven, Git
  |       +-- ./workspace mapped to /config/workspace
  |
  +-- Postgres 16 (labdata) -- schemas raw,stg,dq,mart,ops,mdm,semantic
  +-- MySQL 8.4 (labsource)
  |
  +-- profiles (one at a time):
      orchestration Airflow 3 -> Hop CLI (mounted project)
      streaming Kafka -> Flink SQL
      lakehouse Spark SQL -> Iceberg (local warehouse)
      objectstore MinIO
      metadata OpenMetadata -> own MySQL + Elasticsearch
      observability Grafana -> PostgreSQL
      bi Superset -> PostgreSQL
      identity Keycloak
```

Docker Compose exposes the shared network aliases `postgres`, `mysql`, `kafka`.
No container is granted the host Docker socket or privileged mode.

### Data flow example

`raw.sales_orders` -> Apache Hop Table Input -> `stg.sales_orders`
-> `mart.daily_sales` -> `semantic.v_daily_sales` -> Superset / Grafana.

This is a demonstrator, **not** the final code of any student group's capstone.
Students must implement source-specific extraction, contracts, quality,
identity reconciliation, access tests, and operational logging according to
their approved project charter.
