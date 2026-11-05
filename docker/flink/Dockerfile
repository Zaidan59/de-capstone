FROM flink:1.20.2-scala_2.12-java17
USER root
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates \
  && rm -rf /var/lib/apt/lists/*
RUN curl -fL --retry 4 \
  https://repo.maven.apache.org/maven2/org/apache/flink/flink-sql-connector-kafka/3.4.0-1.20/flink-sql-connector-kafka-3.4.0-1.20.jar \
  -o /opt/flink/lib/flink-sql-connector-kafka-3.4.0-1.20.jar
USER flink
