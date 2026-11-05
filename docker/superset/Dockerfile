FROM apache/superset:6.0.0-dev
USER root
COPY docker/superset/superset_config.py /app/superset_config.py
COPY docker/superset/bootstrap-lab.sh /app/bootstrap-lab.sh
RUN chmod 755 /app/bootstrap-lab.sh && mkdir -p /app/superset_home \
    && chmod 777 /app/superset_home
USER root
