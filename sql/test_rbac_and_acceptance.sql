-- Group A03 RBAC Negative Tests (A03-23) & 3 Consumer Acceptance Tests (A03-32)

-- =========================================================
-- PART 1: RBAC Least-Privilege Verification (tpid_analyst)
-- =========================================================
DO $$
DECLARE
  v_cnt bigint;
  v_denied boolean;
BEGIN
  -- Switch to read-only consumer role
  SET LOCAL ROLE tpid_analyst;

  -- Positive check: tpid_analyst CAN read semantic KPI views & curated star schema
  SELECT COUNT(*) INTO v_cnt FROM semantic.v_kpi_early_intervention_alert;
  IF v_cnt = 0 THEN RAISE EXCEPTION 'RBAC FAIL: tpid_analyst got 0 rows from KPI 3'; END IF;

  SELECT COUNT(*) INTO v_cnt FROM curated.fact_food_supply_daily;
  IF v_cnt = 0 THEN RAISE EXCEPTION 'RBAC FAIL: tpid_analyst got 0 rows from fact_food_supply_daily'; END IF;

  -- Negative check 1: tpid_analyst MUST BE DENIED write on curated
  v_denied := FALSE;
  BEGIN
    INSERT INTO curated.dim_commodity(commodity_code, commodity_name) VALUES ('hack_test', 'Hack');
  EXCEPTION WHEN insufficient_privilege THEN
    v_denied := TRUE;
  END;
  IF NOT v_denied THEN RAISE EXCEPTION 'RBAC FAIL: tpid_analyst was able to INSERT into curated.dim_commodity'; END IF;

  -- Negative check 2: tpid_analyst MUST BE DENIED read on raw schema
  v_denied := FALSE;
  BEGIN
    PERFORM COUNT(*) FROM raw.pihps_market_prices;
  EXCEPTION WHEN insufficient_privilege THEN
    v_denied := TRUE;
  END;
  IF NOT v_denied THEN RAISE EXCEPTION 'RBAC FAIL: tpid_analyst was able to SELECT raw.pihps_market_prices'; END IF;

  -- Negative check 3: tpid_analyst MUST BE DENIED read on stg.quarantine_records
  v_denied := FALSE;
  BEGIN
    PERFORM COUNT(*) FROM stg.quarantine_records;
  EXCEPTION WHEN insufficient_privilege THEN
    v_denied := TRUE;
  END;
  IF NOT v_denied THEN RAISE EXCEPTION 'RBAC FAIL: tpid_analyst was able to SELECT stg.quarantine_records'; END IF;

  -- Negative check 4: tpid_analyst MUST BE DENIED read on ops.run_manifest
  v_denied := FALSE;
  BEGIN
    PERFORM COUNT(*) FROM ops.run_manifest;
  EXCEPTION WHEN insufficient_privilege THEN
    v_denied := TRUE;
  END;
  IF NOT v_denied THEN RAISE EXCEPTION 'RBAC FAIL: tpid_analyst was able to SELECT ops.run_manifest'; END IF;

  RAISE NOTICE 'RBAC NEGATIVE TESTS PASSED (4/4 denials + 2/2 allowed reads)';
END $$;

-- =========================================================
-- PART 2: 3 Consumer Acceptance Tests as tpid_analyst
-- =========================================================
BEGIN;
SET LOCAL ROLE tpid_analyst;

-- Acceptance Test 1 (KPI 3 - Operasi Pasar Murah Early Alerts)
SELECT commodity_code,
       COUNT(*) FILTER (WHERE alert_level = 'ALERT_HIGH') AS alert_high_days,
       COUNT(*) FILTER (WHERE alert_level = 'ALERT_WATCH') AS alert_watch_days,
       MAX(jkt_tradisional_price_rp) AS max_jkt_trad_rp,
       MAX(het_batas_atas_rp) AS het_limit_rp
FROM semantic.v_kpi_early_intervention_alert
WHERE jkt_tradisional_price_rp IS NOT NULL
GROUP BY commodity_code
ORDER BY alert_high_days DESC, commodity_code;

-- Acceptance Test 2 (KPI 1 - Observed Corridor Margin Ratio Only)
SELECT corridor_id,
       commodity_code,
       supplier_region,
       COUNT(*) AS observed_days,
       ROUND(AVG(corridor_produsen_price_rp), 2) AS avg_produsen_rp,
       ROUND(AVG(jkt_tradisional_price_rp), 2) AS avg_jkt_trad_rp,
       ROUND(AVG(supply_chain_margin_ratio), 3) AS avg_margin_ratio
FROM semantic.v_kpi_margin_ratio
GROUP BY corridor_id, commodity_code, supplier_region
ORDER BY corridor_id;

-- Acceptance Test 3 (KPI 2 - Supplier Extreme Weather & Logistics Risk Index)
SELECT corridor_id,
       supplier_region,
       COUNT(*) AS total_days,
       COUNT(*) FILTER (WHERE risk_tier = 'HIGH_RISK') AS high_risk_days,
       COUNT(*) FILTER (WHERE supplier_is_extreme_weather) AS extreme_weather_days,
       ROUND(MAX(weather_logistics_risk_index), 4) AS peak_risk_index
FROM semantic.v_kpi_weather_logistics_risk
GROUP BY corridor_id, supplier_region
ORDER BY peak_risk_index DESC, corridor_id;

COMMIT;
