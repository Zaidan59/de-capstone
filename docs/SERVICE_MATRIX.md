# Service Matrix / Profil Infrastruktur

| Profile | Service | Image/version | Laptop recommendation | Ports localhost |
| --- | --- | --- | --- | --- |
| core | PostgreSQL | postgres:16 | 16 GB host RAM | 55432 |
| core | MySQL | mysql:8.4 | 16 GB host RAM | 53306 |
| core | Webtop XFCE + **VSCodium + Hop 2.19 + Java 21 + Python** | custom Ubuntu XFCE build | 16 GB host RAM | 3001 HTTPS |
| core | CloudBeaver Community | dbeaver/cloudbeaver:latest | 16 GB host RAM | 8978 |
| orchestration | Airflow 3 + bundled Hop CLI/Java21 | custom apache/airflow:3.1.2 | 16-24 GB RAM | 8086 |
| streaming | Kafka 4.1.2 + Flink 1.20.2 | official + connector 3.4.0-1.20 | 24 GB RAM | 29092,8081 |
| lakehouse | Spark 3.5.9 + Iceberg 1.12.0 | custom apache/spark 3.5.9 | 24 GB RAM | no UI; CLI |
| objectstore | MinIO S3 compatible | quay.io/minio/minio (pinned 2025) | 16 GB RAM | 9000,9001 |
| metadata | OpenMetadata 1.12.6 + its own DB + Elasticsearch | optional overlay | 24-32 GB RAM | 8585 |
| observability | Grafana OSS | grafana/grafana-oss:12.2.0 | 16 GB RAM | 3002 |
| bi | Superset 6.0.0-dev | custom superset image | 16-24 GB RAM | 8088 |
| identity | Keycloak 26.4.1 | quay.io/keycloak/keycloak | 16 GB RAM | 8090 |

**Wajib:** core saja. **Opsional:** enable berdasarkan business requirements,
performa PC, dan kesulitan proyek.

**Penting:** Image yang tidak di-pin sampai digest dapat berubah saat registry
memperbarui tag. Untuk semester produksi lab, setelah preflight yang sukses,
kunci digest di deployment institusi. `latest` di CloudBeaver memudahkan akses
rilis Community tetapi mengurangi reproducibility bila image tidak dicache.

OpenMetadata bersifat **eksperimental** dan memerlukan validasi terpisah sebelum
menjadi opsi wajib. Elasticsearch 7.16.3 dalam overlay adalah dependency legacy
lokal untuk kesesuaian versi OpenMetadata 1.12.x, bukan rekomendasi deployment
internet/production. Versi OpenMetadata/Elasticsearch perlu diselaraskan
kembali ketika melakukan upgrade.

Airflow example uses simple `standalone` execution and SQLite metadata for a
local instructional instance, not a secure multi-user scheduler.
