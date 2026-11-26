-- Group A03 Staging, Data Quality Quarantine, Reconciliation, and Run Manifest DDL (idempotent)

CREATE TABLE IF NOT EXISTS ops.run_manifest (
  manifest_id bigserial PRIMARY KEY,
  run_id bigint REFERENCES ops.pipeline_runs(run_id) ON DELETE SET NULL,
  workflow_name text NOT NULL,
  step_name text NOT NULL,
  source_or_target text NOT NULL,
  rows_in bigint NOT NULL DEFAULT 0,
  rows_accepted bigint NOT NULL DEFAULT 0,
  rows_quarantined bigint NOT NULL DEFAULT 0,
  rows_filtered bigint NOT NULL DEFAULT 0,
  status text NOT NULL,
  fallback_used boolean NOT NULL DEFAULT false,
  error_message text,
  started_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz,
  duration_ms bigint
);

CREATE TABLE IF NOT EXISTS stg.food_prices_daily (
  price_date date NOT NULL,
  commodity_code text NOT NULL,
  province_code text NOT NULL,
  market_tier text NOT NULL,
  price_rp numeric(12,2) NOT NULL,
  prev_price_rp numeric(12,2),
  daily_change_pct numeric(10,4),
  source_system text NOT NULL,
  loaded_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (price_date, commodity_code, province_code, market_tier)
);

CREATE TABLE IF NOT EXISTS stg.dki_reference_prices (
  period_type text NOT NULL,
  period_key text NOT NULL,
  wilayah text NOT NULL,
  commodity_code text NOT NULL,
  raw_commodity text NOT NULL,
  price_rp numeric(12,2) NOT NULL,
  source_system text NOT NULL,
  loaded_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (period_type, period_key, wilayah, commodity_code, raw_commodity)
);

CREATE TABLE IF NOT EXISTS stg.weather_daily (
  weather_date date NOT NULL,
  region_key text NOT NULL,
  region_name text NOT NULL,
  temp_max_c numeric(6,2),
  temp_avg_c numeric(6,2),
  precipitation_mm numeric(8,2),
  rain_mm numeric(8,2),
  rain_7d_mm numeric(8,2),
  wind_speed_max_kmh numeric(6,2),
  humidity_avg_pct numeric(5,2),
  is_extreme_weather boolean NOT NULL DEFAULT false,
  source_system text NOT NULL,
  loaded_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (weather_date, region_key)
);

CREATE TABLE IF NOT EXISTS stg.fx_daily (
  rate_date date PRIMARY KEY,
  usd_idr_rate numeric(12,4) NOT NULL,
  source_api text NOT NULL,
  loaded_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS stg.hbkn_daily (
  holiday_date date PRIMARY KEY,
  holiday_names text NOT NULL,
  hbkn_category text NOT NULL,
  is_hbkn_major boolean NOT NULL DEFAULT false,
  loaded_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS stg.quarantine_records (
  quarantine_id bigserial PRIMARY KEY,
  run_id text,
  source_table text NOT NULL,
  business_key text NOT NULL,
  rule_id text NOT NULL,
  severity text NOT NULL,
  raw_payload text,
  reason text NOT NULL,
  quarantined_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS dq.reconciliation_log (
  reconcile_id bigserial PRIMARY KEY,
  run_id text,
  layer_pair text NOT NULL,
  source_table text NOT NULL,
  target_table text NOT NULL,
  rows_in bigint NOT NULL,
  rows_accepted bigint NOT NULL,
  rows_quarantined bigint NOT NULL DEFAULT 0,
  rows_filtered bigint NOT NULL DEFAULT 0,
  delta_rows bigint NOT NULL,
  raw_measure_sum numeric(20,2),
  target_measure_sum numeric(20,2),
  measure_delta numeric(20,2),
  status text NOT NULL,
  checked_at timestamptz NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA stg, dq, ops TO etl_writer;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA stg, dq, ops TO etl_writer;
REVOKE ALL ON stg.quarantine_records FROM tpid_analyst;
REVOKE ALL ON dq.reconciliation_log FROM tpid_analyst;
REVOKE ALL ON ops.run_manifest FROM tpid_analyst;
