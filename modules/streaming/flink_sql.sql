-- Execute via Flink SQL Client after the Kafka topic has been created.
CREATE TABLE asset_metrics (
  event_id STRING,
  asset_id STRING,
  event_time STRING,
  cpu_percent DOUBLE,
  event_ts AS TO_TIMESTAMP(REPLACE(REPLACE(event_time, 'T', ' '), 'Z', '')),
  WATERMARK FOR event_ts AS event_ts - INTERVAL '30' SECOND
) WITH (
  'connector' = 'kafka',
  'topic' = 'capstone.asset.metrics',
  'properties.bootstrap.servers' = 'kafka:9092',
  'properties.group.id' = 'capstone-flink',
  'scan.startup.mode' = 'earliest-offset',
  'format' = 'json'
);
SELECT asset_id,
  window_start,window_end,AVG(cpu_percent) AS avg_cpu,
  COUNT(*) AS samples
FROM TABLE(TUMBLE(TABLE asset_metrics,DESCRIPTOR(event_ts),INTERVAL '1' MINUTE))
GROUP BY asset_id,window_start,window_end;
-- Duplicate events are included here intentionally: add event-ID deduplication
-- in a separate task to demonstrate event-time versus at-least-once semantics.
