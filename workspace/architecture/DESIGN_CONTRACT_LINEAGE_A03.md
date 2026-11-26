# Design Contract, Data Dictionary, DQ Matrix & Lineage (Group A03)

Covers Milestone Tasks: **A03-03** (Grain & Business Keys), **A03-04** (Source-to-Target Mapping), **A03-06** (DQ Rules Matrix), **A03-07** (Dimensional Model & SCD Type-2), **A03-15** (Data Dictionary & Glossary), **A03-25** (Lineage & Change-Impact).

---

## 1. Scope & Target Grain (`A03-03`)
- **5 Strategic Commodities** (`commodity_code`):
  1. `beras` (*Beras*)
  2. `cabai_rawit_merah` (*Cabai Rawit Merah*)
  3. `cabai_merah_keriting` (*Cabai Merah Keriting*)
  4. `bawang_merah` (*Bawang Merah*)
  5. `bawang_putih` (*Bawang Putih*)
- **Fact Table Grain** (`curated.fact_food_supply_daily`):
  - **1 row per `(date_sk, commodity_sk, region_corridor_sk)`** (`full_date × commodity_code × corridor_id`), representing daily DKI Jakarta consumer market price & regulation compliance paired with its supplier corridor (`COR-01..09`) weather/logistics condition.
- **Corridor Join Policy (`active_for_join`)**:
  - `COR-01..04` (`OBSERVED_FDP`, `active_for_join = TRUE`): verified cabai corridors (`Garut`/`Magelang` -> `DKI Jakarta`) allowed to compute `corridor_produsen_price_rp` and `supply_chain_margin_ratio`.
  - `COR-05..09` (`PROPOSED_UNVERIFIED` / `NOT_VERIFIED`, `active_for_join = FALSE`): `corridor_produsen_price_rp` and `supply_chain_margin_ratio` are kept `NULL` (never fabricated or joined as observed supply).
  - `bobot_kontribusi_pasokan` remains `NULL` because official BPS market-wide share weights are unavailable.

---

## 2. Dimensional Star Schema & SCD Type-2 (`A03-07`)

```text
                curated.dim_date_hbkn (date_sk PK)
                             |
curated.dim_commodity -------+------- curated.dim_region_corridor
  (commodity_sk PK)          |          (region_corridor_sk PK)
                             v
                curated.fact_food_supply_daily
                PK: (date_sk, commodity_sk, region_corridor_sk)
                             ^
                             |
  curated.dim_regulation_het +------- curated.dim_macro_logistics
    (regulation_sk PK, SCD2)            (macro_sk PK, BBM SCD2 + FX)
```

- **SCD Type-2 Join Rule (`dim_regulation_het` & BBM in `dim_macro_logistics`)**:
  - Every fact date `full_date` joins strictly via `full_date BETWEEN valid_from AND valid_to` (`9999-12-31` open-ended current rows).
  - For `beras`, `dim_regulation_het` uses `Medium` (`HET Konsumen Zona 1`) as the conservative TPID baseline threshold (`REG-01..04`).
- **Consumer Semantic Views (`semantic.*`)**:
  - `semantic.v_kpi_margin_ratio`: filtered `active_for_join = TRUE` (`COR-01..04`).
  - `semantic.v_kpi_weather_logistics_risk`: filtered `region_key IS NOT NULL` (`COR-01..08`).
  - `semantic.v_kpi_early_intervention_alert`: aggregated to `(full_date, commodity_code)` in DKI Jakarta so multi-corridor commodities never double-count market prices.

---

## 3. Source-to-Target Mapping (`A03-04`)

| Logical Source | Raw Table | Staging Table | Curated Target | Key Standardization Rules |
| :--- | :--- | :--- | :--- | :--- |
| `SRC-01..03` PIHPS BI | `raw.pihps_market_prices`, `raw.pihps_produsen_prices` | `stg.food_prices_daily` | `fact_food_supply_daily` | Unpivot `dki_jakarta`, `jawa_barat`, `jawa_tengah`; `cabai_rawit` -> `cabai_rawit_merah`; `cabai_merah` -> `cabai_merah_keriting`; `ROUND(..., 2)` |
| `SRC-04` Info Pangan / DKI | `raw.info_pangan_jkt`, `raw.dki_harga_pokok_bulanan` | `stg.dki_reference_prices` | Reference / DQ Audit | Filter to strategic commodities; strip `,`; `CABAI RAWIT MERHA` / `CABE` normalization; `N/A` -> `stg.quarantine_records` |
| `SRC-05..07` Open-Meteo | `raw.openmeteo_archive`, `raw.openmeteo_live` | `stg.weather_daily` | `fact_food_supply_daily` | Strip `cuaca <region>.csv` -> `region_key`; deduplicate by priority `archive > live > bmkg`; 7d rolling rain |
| `SRC-08` BMKG Forecast | `raw.bmkg_forecast` | `stg.weather_daily` | `fact_food_supply_daily` | Filter out sentinel `8888`/`9999`; aggregate 3-hourly slots to daily `avg temp`, `sum tp`, `max ws` |
| `SRC-09` USD/IDR FX | `raw.fx_usd_idr` | `stg.fx_daily` | `dim_macro_logistics` | Forward-fill weekends/holidays to daily grain |
| `SRC-10` BBM ESDM | `raw.ref_bbm_esdm` | `raw.ref_bbm_esdm` | `dim_macro_logistics` | Pivot `Biosolar` & `Pertalite` via SCD2 date range |
| `SRC-11` Bapanas HET | `raw.ref_bapanas_het` | `raw.ref_bapanas_het` | `dim_regulation_het` | Map `komoditas` -> canonical `commodity_code`; validate SCD2 intervals |
| `SRC-12` Supply Corridor | `raw.ref_supply_corridor` | `raw.ref_supply_corridor` | `dim_region_corridor` | Enforce `active_for_join` vs `verification_status` |
| `SRC-13` HBKN Calendar | `raw.hbkn_calendar` | `stg.hbkn_daily` | `dim_date_hbkn` | Deduplicate multiple holidays per date; compute `is_pre_hbkn_7d` |

---

## 4. Automated DQ Rules Matrix (`A03-06`)

| Rule ID | Check Description | Target / Scope | Severity | Action |
| :--- | :--- | :--- | :--- | :--- |
| `DQ-01` | Null key or null core measurement (`date`, `commodity`, `region`, `price`, `weather`) | `raw.*` -> `stg.*` | `ERROR` | Quarantine (`stg.quarantine_records`) & log `dq.quality_issues` |
| `DQ-02` | BMKG/sensor sentinel code (`8888`, `9999`) or impossible weather (`rain < 0`, `humidity NOT BETWEEN 0 AND 100`) | `raw.bmkg_forecast`, `raw.openmeteo_*` | `ERROR` | Quarantine & exclude from daily weather aggregation |
| `DQ-03` | Non-positive or non-numeric price (`<= 0`, `N/A`, malformed text) | `raw.pihps_*`, `raw.dki_harga_pokok_bulanan`, `raw.info_pangan_jkt` | `ERROR` | Quarantine & exclude from staging/mart |
| `DQ-04` | Day-over-day price spike or crash `> 300%` (`ABS((p - prev_p)/prev_p) > 3.0`) | `stg.food_prices_daily` | `WARN` / `ERROR` | Flag/quarantine extreme anomalies |
| `DQ-05` | Referential & corridor domain integrity (`commodity_code` in 5 strategic items; `region_key` in 6 known regions; `active_for_join` consistent with `OBSERVED_FDP`) | `stg.*`, `dim_region_corridor` | `ERROR` | Block invalid keys from entering `curated` |
| `DQ-06` | SCD Type-2 validity (`valid_from <= valid_to`, no overlapping intervals for same key) | `raw.ref_bbm_esdm`, `raw.ref_bapanas_het` | `ERROR` | Log failure & prevent ambiguous join |
| `DQ-07` | FX sanity (`usd_idr_rate <= 0` or missing `rate_date`) | `raw.fx_usd_idr` | `ERROR` | Quarantine invalid FX rate |

---

## 5. Data Dictionary & KPI Formulas (`A03-15`)
- **KPI 1 (`supply_chain_margin_ratio`)**: `ROUND(jkt_tradisional_price_rp / NULLIF(corridor_produsen_price_rp, 0), 4)` — hanya dihitung pada koridor `active_for_join = TRUE`.
- **KPI 2 (`weather_logistics_risk_index`)**: Indeks komposit terstandarisasi `[0.00..1.00]` berbasis cuaca sentra (`0.35 * LEAST(rain_7d_mm/150, 1) + 0.25 * LEAST(rain_mm/50, 1) + 0.15 * LEAST(wind_max_kmh/45, 1)`) + tekanan logistik/BBM (`0.15 * LEAST((biosolar - 5150)/2500, 1)`) + kurs (`0.10 * LEAST(GREATEST(usd_idr - 14500, 0)/3500, 1)`).
- **KPI 3 (`early_intervention_alert_flag` & `alert_level`)**:
  - `jkt_tradisional_ma14_rp`: 14-day trailing Moving Average (`13 PRECEDING AND CURRENT ROW`).
  - `jkt_price_dev_ma14_pct`: `((jkt_tradisional_price_rp - jkt_tradisional_ma14_rp) / jkt_tradisional_ma14_rp) * 100`.
  - `ALERT_HIGH`: deviasi `> 15%` vs MA14 **dan** (`supplier_is_extreme_weather = TRUE` **atau** `is_hbkn_major = TRUE` **atau** `is_pre_hbkn_7d = TRUE`), atau deviasi `> 15%` sekaligus melampaui HET/HAP (`is_above_het = TRUE`).
  - `ALERT_WATCH`: deviasi `> 15%` vs MA14 tanpa trigger ganda, atau menembus batas atas HET/HAP.
  - `NORMAL`: kondisi terkendali.

---

## 6. End-to-End Lineage & Change-Impact (`A03-25`)
- **Lineage Chain**:
  `MySQL (labsource) + CSV/XLSX + REST APIs` -> `wf_ingest_all_sources.hwf` (`raw.*`) -> `pl_stg_*.hpl` + `pl_dq_and_reconcile.hpl` (`stg.*`, `stg.quarantine_records`, `dq.*`) -> `pl_load_dimensions.hpl` + `pl_load_fact.hpl` (`curated.*`) -> `semantic.v_kpi_*` -> **Grafana (`:3002`)**.
- **Change-Impact Rules**:
  - Perubahan nama komoditas/wilayah di `SRC-01..04`: cukup update mapping kanonik di `pl_stg_food_prices.hpl`; struktur `curated` dan `semantic` tetap stabil.
  - Perubahan nilai HET/HAP (`SRC-11`) atau tarif BBM (`SRC-10`): tambah baris SCD Type-2 baru dengan `valid_from` efektif & tutup baris lama (`valid_to`, `is_current = FALSE`); histori masa lalu tidak berubah (*non-destructive*).
  - Verifikasi koridor baru (`SRC-12`, mis. jika data FDP BPS untuk beras/bawang merah tervalidasi): ubah `active_for_join = TRUE` di `ref_supply_corridor.csv` dan re-run `wf_main_etl.hwf`; `semantic.v_kpi_margin_ratio` otomatis mencakup koridor baru.
