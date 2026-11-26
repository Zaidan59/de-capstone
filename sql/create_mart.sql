-- Group A03 Curated Star Schema DDL (A03-12, idempotent)
-- Grain of fact_food_supply_daily: (date_sk, commodity_sk, region_corridor_sk)

CREATE SCHEMA IF NOT EXISTS curated;

CREATE TABLE IF NOT EXISTS curated.dim_commodity (
  commodity_sk serial PRIMARY KEY,
  commodity_code text UNIQUE NOT NULL,
  commodity_name text NOT NULL,
  unit text NOT NULL DEFAULT 'Rp/kg',
  is_strategic boolean NOT NULL DEFAULT true,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS curated.dim_region_corridor (
  region_corridor_sk serial PRIMARY KEY,
  corridor_id text UNIQUE NOT NULL,
  region_key text,
  region_name text NOT NULL,
  province_code text,
  province_name text,
  commodity_code text NOT NULL,
  pasar_tujuan text NOT NULL,
  corridor_type text NOT NULL,
  verification_status text NOT NULL,
  active_for_join boolean NOT NULL,
  latitude_ref numeric(9,5),
  longitude_ref numeric(9,5),
  notes text,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS curated.dim_date_hbkn (
  date_sk integer PRIMARY KEY, -- YYYYMMDD
  full_date date UNIQUE NOT NULL,
  year_num integer NOT NULL,
  month_num integer NOT NULL,
  day_num integer NOT NULL,
  day_of_week integer NOT NULL,
  is_weekend boolean NOT NULL,
  is_holiday boolean NOT NULL DEFAULT false,
  holiday_names text,
  hbkn_category text NOT NULL DEFAULT 'NONE',
  is_hbkn_major boolean NOT NULL DEFAULT false,
  is_pre_hbkn_7d boolean NOT NULL DEFAULT false
);

CREATE TABLE IF NOT EXISTS curated.dim_regulation_het (
  regulation_sk serial PRIMARY KEY,
  reg_id text UNIQUE NOT NULL,
  commodity_code text NOT NULL,
  varian_mutu text NOT NULL,
  jenis_batas text NOT NULL,
  batas_bawah_rp numeric(12,2) NOT NULL,
  batas_atas_rp numeric(12,2) NOT NULL,
  dasar_regulasi text NOT NULL,
  valid_from date NOT NULL,
  valid_to date NOT NULL,
  is_current boolean NOT NULL
);

CREATE TABLE IF NOT EXISTS curated.dim_macro_logistics (
  macro_sk integer PRIMARY KEY, -- YYYYMMDD
  full_date date UNIQUE NOT NULL,
  usd_idr_rate numeric(12,4),
  biosolar_rp_per_liter numeric(10,2) NOT NULL,
  pertalite_rp_per_liter numeric(10,2) NOT NULL,
  bbm_regulasi text NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS curated.fact_food_supply_daily (
  date_sk integer NOT NULL REFERENCES curated.dim_date_hbkn(date_sk),
  commodity_sk integer NOT NULL REFERENCES curated.dim_commodity(commodity_sk),
  region_corridor_sk integer NOT NULL REFERENCES curated.dim_region_corridor(region_corridor_sk),
  regulation_sk integer NOT NULL REFERENCES curated.dim_regulation_het(regulation_sk),
  macro_sk integer NOT NULL REFERENCES curated.dim_macro_logistics(macro_sk),
  full_date date NOT NULL,
  jkt_tradisional_price_rp numeric(12,2),
  jkt_modern_price_rp numeric(12,2),
  jkt_tradisional_ma14_rp numeric(12,2),
  jkt_price_dev_ma14_pct numeric(10,4),
  corridor_produsen_price_rp numeric(12,2),
  het_batas_atas_rp numeric(12,2),
  het_compliance_gap_rp numeric(12,2),
  is_above_het boolean,
  supply_chain_margin_ratio numeric(10,4),
  supplier_temp_max_c numeric(6,2),
  supplier_rain_mm numeric(8,2),
  supplier_rain_7d_mm numeric(8,2),
  supplier_wind_max_kmh numeric(6,2),
  supplier_is_extreme_weather boolean NOT NULL DEFAULT false,
  jkt_rain_mm numeric(8,2),
  weather_logistics_risk_index numeric(8,4),
  early_intervention_alert_flag boolean NOT NULL DEFAULT false,
  alert_level text NOT NULL DEFAULT 'NORMAL',
  loaded_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (date_sk, commodity_sk, region_corridor_sk)
);

CREATE INDEX IF NOT EXISTS idx_fact_full_date ON curated.fact_food_supply_daily(full_date);
CREATE INDEX IF NOT EXISTS idx_fact_commodity_date ON curated.fact_food_supply_daily(commodity_sk, full_date);
CREATE INDEX IF NOT EXISTS idx_fact_alert ON curated.fact_food_supply_daily(alert_level, full_date);

-- RBAC enforcement
GRANT USAGE ON SCHEMA curated, semantic TO etl_writer, tpid_analyst;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA curated TO etl_writer;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA curated TO etl_writer;
GRANT SELECT ON ALL TABLES IN SCHEMA curated TO tpid_analyst;
