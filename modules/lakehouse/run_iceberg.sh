#!/usr/bin/env bash
set -euo pipefail
/opt/spark/bin/spark-sql \
  --master local[2] \
  --conf spark.sql.extensions=org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions \
  --conf spark.sql.catalog.lab=org.apache.iceberg.spark.SparkCatalog \
  --conf spark.sql.catalog.lab.type=hadoop \
  --conf spark.sql.catalog.lab.warehouse=file:///opt/lab/warehouse \
  -f /opt/lab/sql/iceberg.sql
