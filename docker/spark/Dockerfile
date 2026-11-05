FROM apache/spark:3.5.9-scala2.12-java17-python3-ubuntu
USER root
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*
RUN curl -fL --retry 4 \
  https://repo.maven.apache.org/maven2/org/apache/iceberg/iceberg-spark-runtime-3.5_2.12/1.12.0/iceberg-spark-runtime-3.5_2.12-1.12.0.jar \
  -o /opt/spark/jars/iceberg-spark-runtime-3.5_2.12-1.12.0.jar
# Launch spark-sql manually through docker compose exec, using local Hadoop catalog.
USER root
