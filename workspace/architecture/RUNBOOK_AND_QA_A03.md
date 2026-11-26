# Operations Runbook, QA Evidence & Handover Guide (Group A03)

Covers Milestone Tasks: **A03-13** (Bootstrap Clean DB), **A03-23** (RBAC Tests), **A03-24** (Master Workflow), **A03-27** (Failure Recovery & Runbook), **A03-28** (Observability & SLO), **A03-29** (DQ Negative Tests), **A03-30** (Final Reconciliation), **A03-31/32** (Grafana Dashboard & 3 Acceptance Tests), **A03-33/34/35** (Clean-Room Demo, Handover & AI Disclosure).

---

## 1. End-to-End Execution & Bootstrap (`A03-13`, `A03-24`, `A03-33`)

### Clean Database Schema Bootstrap (`A03-13`)
All SQL DDL scripts are idempotent and tested against a fresh empty PostgreSQL 16 database (`25` tables/views created cleanly):
```bash
psql -v ON_ERROR_STOP=1 -U labuser -d labdata -f sql/postgres-init/01-create.sql
psql -v ON_ERROR_STOP=1 -U labuser -d labdata -f sql/postgres-init/03-capstone-infra.sql
psql -v ON_ERROR_STOP=1 -U labuser -d labdata -f sql/04-stg-dq-ops-ddl.sql
psql -v ON_ERROR_STOP=1 -U labuser -d labdata -f sql/create_mart.sql
psql -v ON_ERROR_STOP=1 -U labuser -d labdata -f sql/semantic_views.sql
```

### Apache Hop Pipeline Folder Layout (`workspace/hop-project/pipelines/`)
- `pipelines/raw/` (`10` ingestion pipelines for `SRC-01..13`)
- `pipelines/stg/` (`pl_stg_food_prices.hpl`, `pl_stg_weather.hpl`, `pl_stg_macro_ref.hpl`)
- `pipelines/dq/` (`pl_dq_and_reconcile.hpl`)
- `pipelines/curated/` (`pl_load_dimensions.hpl`, `pl_load_fact.hpl`)
- `workflows/wf_main_etl.hwf` — master end-to-end workflow (`raw` -> `stg` -> `dq` -> `curated` -> `ops.run_manifest`)

Run end-to-end inside `workbench`:
```bash
docker compose exec -T -u abc workbench bash -lc \
  'cd /opt/hop && ./hop-run.sh -j capstone-local -e docker-local -r local -f /config/workspace/hop-project/workflows/wf_main_etl.hwf'
```

---

## 2. Failure Handling, Controlled Recovery & Runbook (`A03-27`)

### Resilience Mechanisms
1. **HTTP Retries**: Live API `Rest` transforms (`pl_ingest_bmkg.hpl`, `pl_ingest_openmeteo_live.hpl`) use `retryTimes = 3`, `retryDelayMs = 2000`, `connectionTimeout = 15000`.
2. **Pre-Run Snapshot & Failure-Hop Fallback**: `wf_main_etl.hwf` snapshots `raw.bmkg_forecast` and `raw.openmeteo_live` into `ops.last_good_*` before calling live APIs. If the live endpoint fails, the workflow routes on red failure hop to `Fallback Restore * Snapshot`, records `RECOVERED_FALLBACK` (`fallback_used = TRUE`) in `ops.run_manifest`, and completes downstream staging/mart refresh without breaking KPI consumers.

### Observed Controlled Outage Test (`SIMULATE_BMKG_FAIL=Y`)
- Outage run (`run_id = 4`): `Check BMKG API Gate` triggered failure hop -> `Fallback Restore BMKG Snapshot` restored verified BMKG records (`fallback_used = TRUE`) -> completed end-to-end as `SUCCESS_WITH_FALLBACK` in **`6.959s`** (`13,626` fact rows).
- Post-recovery live run (`run_id = 5`, `SIMULATE_BMKG_FAIL=N`): restored live BMKG ingestion -> completed as `SUCCESS` (`fallback_used = FALSE`) in **`7.455s`**.

### Operator Recovery Runbook
- **Symptom**: `ops.pipeline_runs.status = 'SUCCESS_WITH_FALLBACK'` or `ops.run_manifest.fallback_used = TRUE`.
- **Action**:
  1. Inspect `ops.run_manifest` (`error_message`, `completed_at`).
  2. Test external endpoint reachability from `workbench` (`curl -I https://api.bmkg.go.id/...`).
  3. Re-run `wf_main_etl.hwf` once endpoint recovers and verify `fallback_used = FALSE`.

---

## 3. Observability & SLI/SLO Summary (`A03-28`)
- **End-to-End Runtime SLI (`wf_main_etl`)**: `~7.0s – 8.0s` (well within `< 5 min` batch SLO).
- **Data Freshness**:
  - Live weather (`BMKG` & `Open-Meteo Live`): refreshed daily (`2026-11-18..2026-11-28`).
  - Historical food prices (`PIHPS BI` & `Open-Meteo Archive`): `2022-01-01..2026-02-12`; DKI monthly reference up to `202609`.
- **Reconciliation & Quality Gate**: `100%` (`6/6` layer checks `PASS`, `delta_rows = 0`).

---

## 4. Verification Results (`A03-18`, `A03-23`, `A03-29`, `A03-30`, `A03-32`)
1. **Mart Tests (`sql/mart_tests.sql`)**: **PASS** (`5` commodities, `9` corridors, `1,793` date/macro rows, `12` HET regulations, `13,626` fact rows, zero duplicate grains, zero unverified corridor leakage).
2. **RBAC Negative Tests (`sql/test_rbac_and_acceptance.sql`)**: **PASS** (`SET LOCAL ROLE tpid_analyst`: `2/2` allowed `SELECT` on `curated` & `semantic.v_kpi_*`; `4/4` denied on `INSERT` into `curated` and `SELECT` on `raw.*`, `stg.quarantine_records`, `ops.run_manifest`).
3. **DQ Negative Control (`A03-29`)**: **PASS** — injected negative price (`-500`), BMKG sentinel (`8888`/`9999`), and negative FX (`-1`) into `2099-01-01`; verified quarantine capture (`DQ-03`, `DQ-02`, `DQ-07`) and isolation from `stg.fx_daily` / `curated`, followed by clean removal & re-run.
4. **Final Reconciliation (`A03-30`, `dq.reconciliation_log`)**:
   - `raw.pihps_* (unpivoted) -> stg.food_prices_daily`: `55,576 -> 55,576` (`delta_rows = 0`, `measure_delta = 0.00`, `PASS`)
   - `raw.dki_harga_pokok_bulanan + raw.info_pangan_jkt -> stg.dki_reference_prices`: `4,758 -> 724` accepted + `29` quarantined (`N/A`) + `4,005` non-strategic filtered (`delta_rows = 0`, `PASS`)
   - `raw.openmeteo_* + raw.bmkg_forecast -> stg.weather_daily`: `9,102 -> 9,084` accepted + `18` date-overlap deduplicated (`delta_rows = 0`, `PASS`)
   - `raw.fx_usd_idr -> stg.fx_daily`: `1,250 -> 1,250` (`delta_rows = 0`, `measure_delta = 0.00`, `PASS`)
   - `raw.hbkn_calendar -> stg.hbkn_daily`: `147 -> 145` accepted + `2` same-date holiday deduplicated (`delta_rows = 0`, `PASS`)
   - `stg -> curated.fact_food_supply_daily`: `13,626 -> 13,626` (`delta_rows = 0`, `measure_delta = 0.00`, `PASS`)
5. **Grafana Dashboard (`A03-31`)**:
   - Start profile: `bash scripts/lab.sh up observability` -> `http://127.0.0.1:3002` (`admin` / `GRAFANA_ADMIN_PASSWORD` in `.env`).
   - Provisioned datasource: `config/grafana/provisioning/datasources/postgres.yml` (`uid: de-postgres`).
   - Provisioned dashboard: `config/grafana/provisioning/dashboards/capstone-a03-tpid.json` (`uid: capstone-a03-tpid`).

---

## 5. AI Usage Disclosure (`A03-35`)
- **AI Assistance Scope**: AI tooling assisted with Hop XML pipeline/workflow scaffolding, PostgreSQL Star Schema DDL, semantic KPI view definitions, Grafana dashboard JSON provisioning, SQL test scripts, and documentation synthesis.
- **Verification**: All pipeline runs, DQ rule counts, reconciliation numbers, RBAC denial tests, fallback outage tests, and Grafana live queries were executed directly against the local Docker Compose runtime without fabricated metrics.
