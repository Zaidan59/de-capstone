# Optional Service Operations

Enable only the services actually needed by a group's approved capstone topic.
The commands assume the **core profile is already healthy**.

## Orchestration: Airflow 3 + Apache Hop

```bash
bash scripts/lab.sh up orchestration
```

UI: http://localhost:8086. Look for DAG `capstone_hop_sample` and trigger it
manually. The image installs Java 21 and Hop 2.19, and its boot script registers
project `capstone-local`. **No Docker socket is mounted in Airflow.** The DAG
runs Hop natively, using the same `.hpl`/`.hwf` from `workspace/hop-project`.
Airflow standalone credentials may be generated in its persistent home; inspect
logs in the controlled local environment.

## Streaming: Kafka + Flink SQL

```bash
bash scripts/lab.sh up streaming
docker compose --profile streaming exec -T kafka \
 /opt/kafka/bin/kafka-topics.sh --bootstrap-server kafka:9092 \
 --create --if-not-exists --topic capstone.asset.metrics --partitions 1 --replication-factor 1
cat modules/streaming/kafka_events.jsonl | docker compose --profile streaming exec -T kafka \
 /opt/kafka/bin/kafka-console-producer.sh --bootstrap-server kafka:9092 \
 --topic capstone.asset.metrics
```

Flink UI: http://localhost:8081. Flink SQL Client:

```bash
docker compose --profile streaming exec flink-jobmanager \
 /opt/flink/bin/sql-client.sh -f /opt/lab/streaming/flink_sql.sql
```

A duplicate event and a late event are deliberately present. The SQL example
illustrates event-time windows but does not automatically deduplicate. Document
at-least-once and sink-idempotency policies separately.

## Lakehouse: Spark + Iceberg

```bash
bash scripts/lab.sh up lakehouse
docker compose --profile lakehouse exec spark bash /opt/lab/sql/run_iceberg.sh
```

This runs Spark SQL locally with Iceberg's Hadoop catalog in the mounted
`warehouse/`. It does not require MinIO to demonstrate snapshots/time travel.

## Object storage: MinIO

```bash
bash scripts/lab.sh up objectstore
```

Console: http://localhost:9001. Credentials: `MINIO_USER`, `MINIO_PASSWORD`
in `.env`. Configure S3 integration separately for the group's needs.

## Metadata: OpenMetadata

```bash
bash scripts/lab.sh up metadata
```

UI: http://localhost:8585. The optional overlay has its own metadata DB and
Elasticsearch, and runs a migration step. **This is an experimental local
profile**. First validate against the matching upstream release, especially
search-engine compatibility; it does not include the scheduled ingestion stack.
Students can first produce `modules/metadata/catalog.csv` and `lineage.csv`
without OpenMetadata, and then enter equivalent assets/lineage in the UI.

## Observability: Grafana

```bash
bash scripts/lab.sh up observability
```

UI: http://localhost:3002. Login `admin` with `GRAFANA_ADMIN_PASSWORD`.
The PostgreSQL datasource is provisioned. Use SQL from
`modules/observability/sample_queries.sql` to create panels.

## Serving: Apache Superset

```bash
bash scripts/lab.sh up bi
```

UI: http://localhost:8088. Login `admin` with `SUPERSET_ADMIN_PASSWORD`.
Add PostgreSQL via internal host `postgres:5432`, database `labdata`, using the
project's synthetic credentials. Build a dataset using
`semantic.v_daily_sales`; validate KPI totals independently with SQL.

## Identity: Keycloak (advanced optional)

```bash
bash scripts/lab.sh up identity
```

UI: http://localhost:8090. Bootstrap user `admin` and generated password.
`start-dev` is for local classrooms, not hardened/production identity.

## Stopping and data persistence

```bash
bash scripts/lab.sh stop streaming
bash scripts/lab.sh backup
```

`stop` preserves volumes and workspaces. Avoid running all profiles at once on
student laptops.
