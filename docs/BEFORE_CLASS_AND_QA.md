# Instructor Pre-Class Checklist and Runtime Acceptance

**Every profile must pass on a real Windows and/or Linux Docker Engine.**
YAML parse and XML parse alone do not prove that container images, custom
builds, JDBC drivers, Hop transform IDs, Flink SQL, and Iceberg table features
work at runtime.

## Core acceptance

- [ ] `init` produces .env with non-default random passwords (PowerShell & Bash).
- [ ] `docker compose config --quiet` passes with `.env` present.
- [ ] `up core` completes builds and shows healthy PostgreSQL/MySQL.
- [ ] HTTPS Workbench accessible with local credentials.
- [ ] Actual VSCodium starts from XFCE desktop and can edit mounted files.
- [ ] Apache Hop GUI launches and shows sample `.hpl`/`.hwf`.
- [ ] Python 3, Java 21, javac, Maven, and Git versions shown.
- [ ] CloudBeaver initial setup wizard completes; can query PostgreSQL/MySQL.
- [ ] `preflight` reports **60** `raw.sales_orders` rows and **3** MySQL orders.
- [ ] `hop-demo` runs successfully and output equals 60 staging rows.
- [ ] `backup` creates recoverable SQL file; `reset-demo` preserves workspace.
- [ ] User changes a VSCodium file and sees it on the host (Windows/Linux).

## Optional profile acceptance

- [ ] Airflow 3 UI opens; DAG is parsed; Hop task executes after Hop registration.
- [ ] Kafka topic `capstone.asset.metrics` created; producer/consumer work.
- [ ] Flink SQL client loads Kafka connector, watermark/aggregation query executes.
- [ ] Spark SQL starts; Iceberg table creation/inserts/snapshots succeed.
- [ ] MinIO Console works; bucket object create/read tested.
- [ ] Grafana PostgreSQL datasource connects; dashboard query visible.
- [ ] Superset initializes and can connect PostgreSQL via SQLAlchemy.
- [ ] Keycloak initial administrator login succeeds.
- [ ] OpenMetadata migrate/bootstrap/server healthy; create a catalog entry.

## Clean-state regression

1. Backup any personal work; use a disposable test project.
2. Check free memory/disk and ensure local ports available.
3. `init` -> `up core` -> `preflight` -> `hop-demo`.
4. Stop/restart; check persistence of database and workbench files.
5. Enable **one optional profile at a time**, validate, stop it, continue.
6. Test at least one negative/failure case per selected tool.
7. Record image digests, platform, outcome and differences in
   `docs/RUNTIME_QA_RESULTS_TEMPLATE.csv`.

**Never run `destroy` on a student production project** without exporting data
and ensuring there is a working backup.
