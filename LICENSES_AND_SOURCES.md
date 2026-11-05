# License, Image and Source Provenance

This package distributes original Compose, scripts, SQL, examples and
configuration. It does **not** redistribute font files, container image layers,
Apache Hop binaries, vendor source code, Docker images, or production LABFIK data.

All applications are downloaded by the user's Docker Engine at image-pull/build
execution. Their project/vendor licenses apply independently:

- Apache Hop — Apache License 2.0, 2.19 release
- Apache Airflow, Kafka, Flink, Spark, Iceberg, Superset — Apache 2.0 projects
- VSCodium — official VSCodium repository and component licenses
- CloudBeaver Community — DBeaver Community distribution licenses
- PostgreSQL, MySQL, MinIO, Grafana, OpenMetadata, Keycloak — vendor/project terms
- LinuxServer Webtop — LinuxServer distribution and component terms

Official references (versions checked in October 2026):
- https://hop.apache.org/download/
- https://hop.apache.org/manual/latest/
- https://vscodium.com/install
- https://repo.vscodium.dev/
- https://docs.linuxserver.io/images/docker-webtop/
- https://github.com/dbeaver/cloudbeaver/wiki/CloudBeaver-Community-deployment-from-docker-image
- https://airflow.apache.org/docs/
- https://kafka.apache.org/documentation/
- https://nightlies.apache.org/flink/flink-docs-release-1.20/
- https://spark.apache.org/docs/3.5.9/
- https://iceberg.apache.org/releases/
- https://docs.open-metadata.org/v1.12.x/deployment/docker
- https://grafana.com/docs/grafana/latest/
- https://superset.apache.org/docs/

Before classroom deployment, independently confirm support/security status of
pinned dependencies. This is a teaching sample and not a production system.
