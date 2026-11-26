-- Group A03 Automated Mart & RBAC Verification Tests (A03-18, A03-23)
-- Every test assertion fails with SQLSTATE P0001 if violated.

DO $$
DECLARE
  v_cnt bigint;
BEGIN
  -- 1. Dimension non-empty checks
  SELECT COUNT(*) INTO v_cnt FROM curated.dim_commodity;
  IF v_cnt <> 5 THEN RAISE EXCEPTION 'TEST FAIL: expected 5 strategic commodities, got %', v_cnt; END IF;

  SELECT COUNT(*) INTO v_cnt FROM curated.dim_region_corridor;
  IF v_cnt <> 9 THEN RAISE EXCEPTION 'TEST FAIL: expected 9 corridors (COR-01..09), got %', v_cnt; END IF;

  SELECT COUNT(*) INTO v_cnt FROM curated.dim_date_hbkn;
  IF v_cnt = 0 THEN RAISE EXCEPTION 'TEST FAIL: dim_date_hbkn is empty'; END IF;

  SELECT COUNT(*) INTO v_cnt FROM curated.dim_regulation_het;
  IF v_cnt <> 12 THEN RAISE EXCEPTION 'TEST FAIL: expected 12 regulation rows, got %', v_cnt; END IF;

  SELECT COUNT(*) INTO v_cnt FROM curated.dim_macro_logistics;
  IF v_cnt = 0 THEN RAISE EXCEPTION 'TEST FAIL: dim_macro_logistics is empty'; END IF;

  -- 2. Fact non-empty & grain uniqueness
  SELECT COUNT(*) INTO v_cnt FROM curated.fact_food_supply_daily;
  IF v_cnt = 0 THEN RAISE EXCEPTION 'TEST FAIL: fact_food_supply_daily is empty'; END IF;

  SELECT COUNT(*) INTO v_cnt FROM (
    SELECT date_sk, commodity_sk, region_corridor_sk
    FROM curated.fact_food_supply_daily
    GROUP BY 1, 2, 3 HAVING COUNT(*) > 1
  ) dup;
  IF v_cnt > 0 THEN RAISE EXCEPTION 'TEST FAIL: duplicate grain rows in fact_food_supply_daily: %', v_cnt; END IF;

  -- 3. Unverified corridor isolation (active_for_join=FALSE must NEVER compute margin ratio)
  SELECT COUNT(*) INTO v_cnt
  FROM curated.fact_food_supply_daily f
  JOIN curated.dim_region_corridor rc ON rc.region_corridor_sk = f.region_corridor_sk
  WHERE rc.active_for_join = FALSE
    AND (f.corridor_produsen_price_rp IS NOT NULL OR f.supply_chain_margin_ratio IS NOT NULL);
  IF v_cnt > 0 THEN RAISE EXCEPTION 'TEST FAIL: unverified corridor leaked produsen/margin values: % rows', v_cnt; END IF;

  -- 4. Semantic KPI view grain integrity (KPI 3 must have <= 1 row per date x commodity)
  SELECT COUNT(*) INTO v_cnt FROM (
    SELECT full_date, commodity_code
    FROM semantic.v_kpi_early_intervention_alert
    GROUP BY 1, 2 HAVING COUNT(*) > 1
  ) dup_kpi3;
  IF v_cnt > 0 THEN RAISE EXCEPTION 'TEST FAIL: duplicate rows in v_kpi_early_intervention_alert: %', v_cnt; END IF;

  -- 5. Zero reconciliation delta check (for latest batch)
  SELECT COUNT(*) INTO v_cnt
  FROM dq.reconciliation_log
  WHERE status <> 'PASS' AND reconcile_id IN (
    SELECT MAX(reconcile_id) FROM dq.reconciliation_log GROUP BY layer_pair, source_table
  );
  IF v_cnt > 0 THEN RAISE EXCEPTION 'TEST FAIL: latest reconciliation has % non-PASS rows', v_cnt; END IF;

  RAISE NOTICE 'ALL MART TESTS PASSED';
END $$;
