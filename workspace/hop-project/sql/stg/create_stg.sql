CREATE SCHEMA IF NOT EXISTS stg;
CREATE OR REPLACE FUNCTION stg.safe_date(x text) RETURNS date LANGUAGE plpgsql IMMUTABLE AS $$
BEGIN RETURN x::date; EXCEPTION WHEN others THEN RETURN NULL; END $$;
CREATE OR REPLACE FUNCTION stg.safe_ts(x text) RETURNS timestamp LANGUAGE plpgsql IMMUTABLE AS $$
BEGIN RETURN x::timestamp; EXCEPTION WHEN others THEN RETURN NULL; END $$;
CREATE OR REPLACE FUNCTION stg.safe_num(x text) RETURNS numeric LANGUAGE sql IMMUTABLE AS $$
SELECT CASE WHEN trim(x) ~ '^-?[0-9]+(\.[0-9]+)?$' THEN trim(x)::numeric END $$;
CREATE OR REPLACE FUNCTION stg.safe_month(x text) RETURNS date LANGUAGE sql IMMUTABLE AS $$
SELECT CASE WHEN trim(x) ~ '^[0-9]{6}(\.0+)?$' THEN
  CASE WHEN substr(trim(x),5,2)::int BETWEEN 1 AND 12 THEN to_date(substr(trim(x),1,6) || '01', 'YYYYMMDD') END
END $$;
CREATE TABLE IF NOT EXISTS stg.price_pihps (
  source_id text NOT NULL, market_tier text NOT NULL, commodity_key text NOT NULL, price_date date,
  region_key text NOT NULL, price_rp numeric(14,2),
  run_id integer, raw_ingested_at timestamptz, stg_loaded_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS stg.price_dki_monthly (
  source_id text NOT NULL, period_month date, region_name text, commodity_raw text, commodity_std text,
  price_raw text, price_rp numeric(14,2), price_status text,
  run_id integer, raw_ingested_at timestamptz, stg_loaded_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS stg.price_info_pangan_jkt (
  source_id text NOT NULL, period_year integer, commodity_std text, price_raw text, price_rp numeric(14,2),
  run_id integer, raw_ingested_at timestamptz, stg_loaded_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS stg.weather_daily (
  source_id text NOT NULL, region_key text, weather_date date, temp_max_c numeric(6,2),
  precip_mm numeric(8,2), rain_mm numeric(8,2), data_origin text, http_status integer,
  run_id integer, raw_ingested_at timestamptz, stg_loaded_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS stg.bmkg_forecast (
  source_id text NOT NULL, region_key text, adm4_code text, regency_name text,
  local_datetime timestamp, utc_datetime timestamp, temp_c double precision, humidity_pct double precision,
  rain_mm double precision, wind_kmh double precision, cloud_pct double precision,
  weather_code integer, weather_desc text, http_status integer,
  run_id integer, raw_ingested_at timestamptz, stg_loaded_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS stg.fx_usd_idr (
  source_id text NOT NULL, rate_date date, base_currency text, quote_currency text,
  usd_idr_rate numeric(14,4), source_api text,
  run_id integer, raw_ingested_at timestamptz, stg_loaded_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS stg.hbkn_calendar (
  source_id text NOT NULL, holiday_date date, holiday_year integer, local_name text, name_en text,
  hbkn_category text, is_hbkn_major boolean, is_fixed boolean, is_global boolean,
  run_id integer, raw_ingested_at timestamptz, stg_loaded_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS stg.ref_bbm_esdm (
  source_id text NOT NULL, bbm_id text, fuel_type text, fuel_category text, price_per_liter numeric(12,2),
  regulation_basis text, valid_from date, valid_to date, is_current boolean,
  run_id integer, raw_ingested_at timestamptz, stg_loaded_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS stg.ref_bapanas_het (
  source_id text NOT NULL, reg_id text, commodity_raw text, quality_variant text, limit_type text,
  lower_limit_rp numeric(14,2), upper_limit_rp numeric(14,2), regulation_basis text,
  valid_from date, valid_to date, is_current boolean,
  run_id integer, raw_ingested_at timestamptz, stg_loaded_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS stg.ref_supply_corridor (
  source_id text NOT NULL, corridor_id text, commodity_code text, commodity_raw text, region_code text,
  regency_name text, province_name text, destination_market text,
  latitude double precision, longitude double precision, corridor_type text, verification_status text,
  active_for_join boolean, contribution_weight double precision, weight_scope text, weight_period text,
  run_id integer, raw_ingested_at timestamptz, stg_loaded_at timestamptz NOT NULL DEFAULT now());
