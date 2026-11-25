# Snapshot & Source Manifest (`D03`) — Capstone Group A03

Seluruh dataset di bawah ini berada di `workspace/data/`, bersifat publik/regulasi/terverifikasi **bebas PII dan credential**, serta siap dipakai untuk menjalankan ulang pipeline secara reproduksibel (termasuk saat mode *offline snapshot fallback*).

---

## 1. Inventaris Sumber Data (`SRC-01` .. `SRC-13`)

| Source ID | File / Lokasi di `workspace/data/` | Klasifikasi | Rentang / Versi Data | Jumlah Baris | Target `raw.*` & Script / Pipeline |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`SRC-01`** | `food_prices/pasar_tradisional/Cleaned_After_Imputation/*.csv` (10 file; 5 strategis dipakai) | `PUBLIC_OPEN` | `2022-01-01` .. `2026-02-12` | 1.415–1.417 / komoditas | MySQL `src_tradisional_*` (`load_food_to_mysql.py`) → `raw.pihps_market_prices` (`pl_ingest_pihps_mysql.hpl`) |
| **`SRC-02`** | `food_prices/pasar_modern/Cleaned_After_Imputation/*.csv` (10 file; 5 strategis dipakai) | `PUBLIC_OPEN` | `2022-01-01` .. `2026-02-12` | 1.493 / komoditas | MySQL `src_modern_*` (`load_food_to_mysql.py`) → `raw.pihps_market_prices` (`pl_ingest_pihps_mysql.hpl`) |
| **`SRC-03`** | `food_prices/produsen/Cleaned_After_Imputation/*.csv` (10 file; 4 domestik Jabar/Jateng) | `PUBLIC_OPEN` | `2022-01-01` .. `2026-02-12` | 1.493 / komoditas (**5.972** total di `raw`) | `raw.pihps_produsen_prices` (`pl_ingest_pihps_produsen.hpl`). *(CSV `bawang_putih` produsen hanya berisi Kalut & NTB)* |
| **`SRC-04`** | `info_pangan_jkt.xlsx` & `data-harga-bahan-pokok-di-provinsi-dki-jakarta-komponen-data.xlsx` | `PUBLIC_OPEN` | Tahunan `2023` (`info_pangan_jkt`) & Bulanan `202501..202609` | **33** & **4.725** | `raw.info_pangan_jkt` (`pl_ingest_info_pangan_jkt.hpl`) & `raw.dki_harga_pokok_bulanan` (`pl_ingest_dki_komponen.hpl`) |
| **`SRC-05..07`** *(Arsip)* | `weather/cuaca {garut,magelang,karawang,indramayu,brebes,dki_jakarta}.csv` (6 file) | `PUBLIC_OPEN` | `2022-01-01` .. `2026-02-12` | 1.504 / wilayah (**9.024** total) | `raw.openmeteo_archive` (`pl_ingest_openmeteo_archive.hpl`; skip 3 baris metadata atas) |
| **`SRC-05..07`** *(Live)* | `weather/openmeteo_live_latest.csv` (snapshot fallback) + Live REST API Open-Meteo | `PUBLIC_OPEN` | Rolling 7 hari lalu + 3 hari prakiraan | **60** (10 × 6 wilayah) | `raw.openmeteo_live` (`pl_ingest_openmeteo_live.hpl`, `fetch_openmeteo_weather.py`) |
| **`SRC-08`** | `bmkg_station_ref.csv` (snapshot fallback) + Live REST API BMKG | `PUBLIC_OPEN` | Prakiraan 3-jam-an (`live-forecast`) | **120** (6 wilayah `adm4`) | `raw.bmkg_forecast` (`pl_ingest_bmkg.hpl`, `fetch_bmkg_forecast.py`) |
| **`SRC-09`** | `bi_jisdor_daily.csv` (Frankfurter historis + `open.er-api.com` live) | `PUBLIC_OPEN` | `2021-12-31` .. `2026-11-18` (`daily-fx`) | **1.250** | `raw.fx_usd_idr` (`pl_ingest_fx.hpl`, `fetch_fx_usd_idr.py`) |
| **`SRC-10`** | `ref_bbm_esdm.csv` | `PUBLIC_REGULATION` | `2022-01-01` .. `9999-12-31` (`scd2-v1`) | **4** | `raw.ref_bbm_esdm` (`pl_ingest_references.hpl`) |
| **`SRC-11`** | `ref_bapanas_het.csv` | `PUBLIC_REGULATION` | `2022-01-01` .. `9999-12-31` (`scd2-v1`) | **12** | `raw.ref_bapanas_het` (`pl_ingest_references.hpl`) |
| **`SRC-12`** | `ref_supply_corridor.csv` | `PROJECT_ASSUMPTION` | `fdp-2024-v1` (`COR-01..09`) | **9** (`4` `OBSERVED_FDP`, `5` unverified) | `raw.ref_supply_corridor` (`pl_ingest_references.hpl`) |
| **`SRC-13`** | `ref_hbkn_calendar.csv` (Google Calendar ID + Nager.Date) | `PUBLIC_OPEN` | `2022` .. `2026` | **147** | `raw.hbkn_calendar` (`pl_ingest_hbkn.hpl`, `fetch_hbkn_holidays.py`) |

---

## 2. Sampel Sintetis Starter Lab (`SYNTHETIC_DEMO`)

- `sql/mysql-init/01-source.sql` (`demo_customers`: 3 baris, `demo_orders`: 3 baris) dan `sql/postgres-init/02-demo.sql` (`raw.sales_orders`: 60 baris, `mart.daily_sales`: 6 baris) hanya digunakan oleh `scripts/lab.sh preflight` dan `hop-demo` untuk uji konektivitas awal.
- File sintetis non-proyek (`ocs_assets_synthetic.csv`, `zabbix_trends_synthetic.csv`, `sales_events.jsonl`) sudah dihapus dari `workspace/data/`.

---

## 3. Perintah Menjalankan Ulang Pipeline dari Snapshot Aman

```bash
# 1. Muat 17 tabel harga pangan ke MySQL labsource
bash scripts/lab.sh seed-food

# 2. (Opsional) Segarkan snapshot CSV dari API publik
docker compose exec -T -u abc workbench python /config/workspace/python/fetch_openmeteo_weather.py
docker compose exec -T -u abc workbench python /config/workspace/python/fetch_bmkg_forecast.py
docker compose exec -T -u abc workbench python /config/workspace/python/fetch_fx_usd_idr.py
docker compose exec -T -u abc workbench python /config/workspace/python/fetch_hbkn_holidays.py

# 3. Jalankan master workflow Apache Hop (13 sumber -> 12 tabel raw.* + ops.pipeline_runs/watermarks)
docker compose exec -T -u abc workbench bash -lc 'cd /opt/hop && ./hop-run.sh -j capstone-local -e docker-local -r local -f /config/workspace/hop-project/workflows/wf_ingest_all_sources.hwf'
```
