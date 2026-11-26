-- Group A03 Semantic KPI Views & Observability Views (A03-19, A03-20, A03-21, A03-22)

CREATE SCHEMA IF NOT EXISTS semantic;

-- KPI 1: Supply Chain Margin Ratio (strictly observed active corridors only: COR-01..04)
CREATE OR REPLACE VIEW semantic.v_kpi_margin_ratio AS
SELECT
  f.full_date,
  d.is_hbkn_major,
  d.is_pre_hbkn_7d,
  c.commodity_code,
  c.commodity_name,
  rc.corridor_id,
  rc.region_name AS supplier_region,
  rc.province_name AS supplier_province,
  rc.pasar_tujuan,
  rc.verification_status,
  f.corridor_produsen_price_rp,
  f.jkt_tradisional_price_rp,
  f.jkt_modern_price_rp,
  f.supply_chain_margin_ratio,
  ROUND(((f.jkt_tradisional_price_rp - f.corridor_produsen_price_rp) / NULLIF(f.corridor_produsen_price_rp, 0)) * 100.0, 2) AS margin_pct_vs_produsen,
  ROUND(((f.jkt_modern_price_rp - f.jkt_tradisional_price_rp) / NULLIF(f.jkt_tradisional_price_rp, 0)) * 100.0, 2) AS modern_spread_pct_vs_tradisional
FROM curated.fact_food_supply_daily f
JOIN curated.dim_date_hbkn d ON d.date_sk = f.date_sk
JOIN curated.dim_commodity c ON c.commodity_sk = f.commodity_sk
JOIN curated.dim_region_corridor rc ON rc.region_corridor_sk = f.region_corridor_sk
WHERE rc.active_for_join = TRUE
  AND f.corridor_produsen_price_rp IS NOT NULL;

-- KPI 2: Supplier Extreme Weather & Logistics Risk Index (COR-01..08 with known supplier coordinates)
CREATE OR REPLACE VIEW semantic.v_kpi_weather_logistics_risk AS
SELECT
  f.full_date,
  c.commodity_code,
  c.commodity_name,
  rc.corridor_id,
  rc.region_key,
  rc.region_name AS supplier_region,
  rc.province_name AS supplier_province,
  rc.active_for_join,
  f.supplier_temp_max_c,
  f.supplier_rain_mm,
  f.supplier_rain_7d_mm,
  f.supplier_wind_max_kmh,
  f.supplier_is_extreme_weather,
  f.jkt_rain_mm,
  m.usd_idr_rate,
  m.biosolar_rp_per_liter,
  m.pertalite_rp_per_liter,
  f.weather_logistics_risk_index,
  CASE
    WHEN f.weather_logistics_risk_index >= 0.70 THEN 'HIGH_RISK'
    WHEN f.weather_logistics_risk_index >= 0.40 THEN 'MODERATE_RISK'
    ELSE 'LOW_RISK'
  END AS risk_tier
FROM curated.fact_food_supply_daily f
JOIN curated.dim_commodity c ON c.commodity_sk = f.commodity_sk
JOIN curated.dim_region_corridor rc ON rc.region_corridor_sk = f.region_corridor_sk
JOIN curated.dim_macro_logistics m ON m.macro_sk = f.macro_sk
WHERE rc.region_key IS NOT NULL;

-- KPI 3: Early Market Intervention Alert (DKI Jakarta daily grain per commodity: zero corridor double-counting)
CREATE OR REPLACE VIEW semantic.v_kpi_early_intervention_alert AS
SELECT
  f.full_date,
  d.is_hbkn_major,
  d.is_pre_hbkn_7d,
  d.holiday_names,
  c.commodity_code,
  c.commodity_name,
  MAX(f.jkt_tradisional_price_rp) AS jkt_tradisional_price_rp,
  MAX(f.jkt_modern_price_rp) AS jkt_modern_price_rp,
  MAX(f.jkt_tradisional_ma14_rp) AS jkt_tradisional_ma14_rp,
  MAX(f.jkt_price_dev_ma14_pct) AS jkt_price_dev_ma14_pct,
  MAX(r.reg_id) AS reg_id,
  MAX(r.dasar_regulasi) AS dasar_regulasi,
  MAX(f.het_batas_atas_rp) AS het_batas_atas_rp,
  MAX(f.het_compliance_gap_rp) AS het_compliance_gap_rp,
  BOOL_OR(f.is_above_het) AS is_above_het,
  BOOL_OR(f.supplier_is_extreme_weather) AS any_supplier_extreme_weather,
  MAX(f.weather_logistics_risk_index) AS max_supplier_risk_index,
  BOOL_OR(f.early_intervention_alert_flag) AS early_intervention_alert_flag,
  CASE
    WHEN BOOL_OR(f.alert_level = 'ALERT_HIGH') THEN 'ALERT_HIGH'
    WHEN BOOL_OR(f.alert_level = 'ALERT_WATCH') THEN 'ALERT_WATCH'
    ELSE 'NORMAL'
  END AS alert_level
FROM curated.fact_food_supply_daily f
JOIN curated.dim_date_hbkn d ON d.date_sk = f.date_sk
JOIN curated.dim_commodity c ON c.commodity_sk = f.commodity_sk
JOIN curated.dim_regulation_het r ON r.regulation_sk = f.regulation_sk
GROUP BY f.full_date, d.is_hbkn_major, d.is_pre_hbkn_7d, d.holiday_names, c.commodity_code, c.commodity_name;

-- Governance & Ops summary views (for observability dashboards; restricted from tpid_analyst)
CREATE OR REPLACE VIEW semantic.v_dq_reconciliation_latest AS
SELECT
  reconcile_id,
  run_id,
  layer_pair,
  source_table,
  target_table,
  rows_in,
  rows_accepted,
  rows_quarantined,
  rows_filtered,
  delta_rows,
  raw_measure_sum,
  target_measure_sum,
  measure_delta,
  status,
  checked_at
FROM dq.reconciliation_log
ORDER BY reconcile_id DESC;

CREATE OR REPLACE VIEW semantic.v_ops_run_slo AS
SELECT
  manifest_id,
  run_id,
  workflow_name,
  step_name,
  source_or_target,
  rows_in,
  rows_accepted,
  rows_quarantined,
  rows_filtered,
  status,
  fallback_used,
  duration_ms,
  started_at,
  completed_at
FROM ops.run_manifest
ORDER BY manifest_id DESC;

-- RBAC: tpid_analyst only gets SELECT on the 3 consumer KPI views (and curated star schema)
GRANT SELECT ON semantic.v_kpi_margin_ratio,
                semantic.v_kpi_weather_logistics_risk,
                semantic.v_kpi_early_intervention_alert TO tpid_analyst;
GRANT SELECT ON semantic.v_dq_reconciliation_latest, semantic.v_ops_run_slo TO etl_writer;
REVOKE ALL ON semantic.v_dq_reconciliation_latest, semantic.v_ops_run_slo, semantic.v_data_quality FROM tpid_analyst;
