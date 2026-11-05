FROM eclipse-temurin:21-jre AS jre
FROM apache/airflow:3.1.2
ARG HOP_VERSION=2.19.0
USER root
COPY --from=jre /opt/java/openjdk /opt/java/openjdk
ENV JAVA_HOME=/opt/java/openjdk
ENV PATH="/opt/java/openjdk/bin:${PATH}"
RUN apt-get update && apt-get install -y --no-install-recommends curl unzip \
    && rm -rf /var/lib/apt/lists/*
RUN curl -fL --retry 4 \
       "https://downloads.apache.org/hop/${HOP_VERSION}/apache-hop-client-${HOP_VERSION}.zip" \
       -o /tmp/hop.zip \
    && unzip -q /tmp/hop.zip -d /opt \
    && chmod -R a+rX /opt/hop \
    && rm -f /tmp/hop.zip
COPY docker/airflow/bootstrap.sh /usr/local/bin/bootstrap-airflow.sh
RUN chmod 755 /usr/local/bin/bootstrap-airflow.sh
USER airflow
