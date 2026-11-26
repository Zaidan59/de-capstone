# Capstone Project Data Engineering — GROUP A03

> **Pembangunan Governed Data Mart Multi-Sumber dan Pipeline Hybrid Live-Batch untuk Pemantauan Volatilitas Harga Pangan, Anomali Iklim Sentra Pemasok, dan Peringatan Dini Intervensi Pasar DKI Jakarta**  
> Mata Kuliah: Data Engineering (S1 Sistem Informasi) — Edisi 2026

---

## 👥 Tim Penyusun (GROUP A03)

| NIM | Nama |
| :--- | :--- |
| **2410512043** | Muhammad Zaidan |
| **2410512060** | Fia Dwi Agustina |
| **2410512074** | Fadjar Malik Fadhilah |
| **2410512075** | Muhammad Ghalib Rafiqi |
| **2410512087** | Imam Hermawan Putra |

---

## 🚀 Panduan Mulai Cepat (Linux & Windows)

Project ini menggunakan profil **Mandatory Core** (`postgres`, `mysql`, `workbench`, `cloudbeaver`) agar ringan di laptop RAM 8–16 GB. Ikuti langkah berikut secara berurutan setelah `git clone` di komputer masing-masing.

### 1. Prasyarat Sistem
- **Windows**: Docker Desktop (backend **WSL2** aktif), PowerShell 5.1+ atau Git Bash. *(Disarankan clone di path lokal seperti `C:\Projects\de-capstone`, hindari folder sync OneDrive.)*
- **Linux**: Docker Engine + Docker Compose Plugin.
- **RAM**: minimal 8–16 GB disarankan, serta internet stabil pada build pertama & saat menjalankan pipeline Live REST API.

### 2. Clone Repository
```bash
git clone https://github.com/Zaidan59/de-capstone.git
cd de-capstone
```
*(File `.gitattributes` otomatis menjaga line-ending `LF` untuk seluruh script Linux agar aman saat di-clone dari Windows.)*

### 3. Inisialisasi Environment (`.env`)
Generate file `.env` lokal dengan password acak:
- **Linux / macOS / Git Bash**:
  ```bash
  bash scripts/lab.sh init
  # Opsional (Linux): sesuaikan PUID dan PGID di .env agar sama dengan `id -u` / `id -g`
  ```
- **Windows PowerShell**:
  ```powershell
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\lab.ps1 init
  ```

> [!IMPORTANT]
> File `.env` bersifat lokal/privat dan **tidak boleh di-commit** ke Git. Mengubah atau membuat ulang `.env` (misalnya saat *clone* ulang di PC yang sama) setelah volume Docker pertama kali terbuat tidak otomatis mengubah password user di dalam volume `pg_data`/`mysql_data`—dan dapat memicu error `Access denied` / `password authentication failed`. Jika ingin reset bersih volume DB agar sinkron dengan `.env` baru:
> ```bash
> docker compose down
> docker volume rm de-capstone-lab_mysql_data de-capstone-lab_pg_data
> ```

### 4. Nyalakan Layanan Inti (`up core`)
Membangun dan menjalankan PostgreSQL 16, MySQL 8.4, CloudBeaver, serta Webtop Workbench (XFCE + VSCodium + Apache Hop 2.19 + MySQL JDBC driver + Python + Java 21):
- **Linux / macOS / Git Bash**:
  ```bash
  bash scripts/lab.sh up core
  ```
- **Windows PowerShell**:
  ```powershell
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\lab.ps1 up core
  ```

### 5. Verifikasi, Setup Apache Hop & Muat Data Sumber
Tunggu beberapa detik setelah `up core` selesai hingga container `workbench` siap, lalu jalankan secara berurutan:

- **Linux / macOS / Git Bash**:
  ```bash
  bash scripts/lab.sh preflight     # Cek koneksi baseline (expected: 60 PostgreSQL, 3 MySQL)
  bash scripts/lab.sh hop-demo      # Registrasi Hop (capstone-local + docker-local) & uji baseline (60 baris)
  bash scripts/lab.sh seed-food     # Muat 17 tabel harga pangan ke MySQL labsource

  # Jalankan DDL Staging, DQ, Curated Mart, & Semantic Views (idempoten):
  docker compose exec -T postgres psql -v ON_ERROR_STOP=1 -U labuser -d labdata -f /dev/stdin < sql/04-stg-dq-ops-ddl.sql
  docker compose exec -T postgres psql -v ON_ERROR_STOP=1 -U labuser -d labdata -f /dev/stdin < sql/create_mart.sql
  docker compose exec -T postgres psql -v ON_ERROR_STOP=1 -U labuser -d labdata -f /dev/stdin < sql/semantic_views.sql

  # Jalankan master workflow end-to-end (raw -> stg -> DQ & rekonsiliasi -> curated mart -> ops):
  docker compose exec -T -u abc workbench bash -lc 'cd /opt/hop && ./hop-run.sh -j capstone-local -e docker-local -r local -f /config/workspace/hop-project/workflows/wf_main_etl.hwf'

  # Verifikasi integritas mart, RBAC negative tests, & 3 acceptance tests TPID:
  docker compose exec -T postgres psql -v ON_ERROR_STOP=1 -U labuser -d labdata -f /dev/stdin < sql/mart_tests.sql
  docker compose exec -T postgres psql -v ON_ERROR_STOP=1 -U labuser -d labdata -f /dev/stdin < sql/test_rbac_and_acceptance.sql

  # Nyalakan Grafana Dashboard (http://localhost:3002):
  bash scripts/lab.sh up observability

  # Opsional: segarkan file snapshot CSV API di workspace/data/ sesuai sumbernya:
  docker compose exec -T -u abc workbench python /config/workspace/python/fetch_openmeteo_weather.py
  docker compose exec -T -u abc workbench python /config/workspace/python/fetch_bmkg_forecast.py
  docker compose exec -T -u abc workbench python /config/workspace/python/fetch_fx_usd_idr.py
  docker compose exec -T -u abc workbench python /config/workspace/python/fetch_hbkn_holidays.py
  ```

- **Windows PowerShell**:
  ```powershell
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\lab.ps1 preflight
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\lab.ps1 hop-demo
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\lab.ps1 seed-food

  # Terapkan DDL Staging, Curated Mart, & Semantic Views:
  Get-Content sql\04-stg-dq-ops-ddl.sql | docker compose exec -T postgres psql -v ON_ERROR_STOP=1 -U labuser -d labdata
  Get-Content sql\create_mart.sql | docker compose exec -T postgres psql -v ON_ERROR_STOP=1 -U labuser -d labdata
  Get-Content sql\semantic_views.sql | docker compose exec -T postgres psql -v ON_ERROR_STOP=1 -U labuser -d labdata

  # Jalankan master workflow end-to-end (raw -> stg -> DQ -> curated -> ops):
  docker compose exec -T -u abc workbench bash -lc "cd /opt/hop && ./hop-run.sh -j capstone-local -e docker-local -r local -f /config/workspace/hop-project/workflows/wf_main_etl.hwf"

  # Nyalakan Grafana Dashboard (http://localhost:3002):
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\lab.ps1 up observability

  # Opsional: segarkan snapshot CSV API (Open-Meteo, BMKG, USD/IDR, HBKN):
  docker compose exec -T -u abc workbench python /config/workspace/python/fetch_openmeteo_weather.py
  docker compose exec -T -u abc workbench python /config/workspace/python/fetch_bmkg_forecast.py
  docker compose exec -T -u abc workbench python /config/workspace/python/fetch_fx_usd_idr.py
  docker compose exec -T -u abc workbench python /config/workspace/python/fetch_hbkn_holidays.py
  ```

> [!WARNING]
> **Penyebab Umum Pipeline `.hpl` Gagal di Hop GUI:**
> 1. **Langsung Run `.hpl` sebelum `wf_ingest_all_sources.hwf` pernah jalan** — tabel `raw.*` di PostgreSQL dibuat otomatis oleh action `Ensure raw tables` di dalam `wf_ingest_all_sources.hwf`, bukan oleh `.hpl` satuan (`relation "raw.xxx" does not exist`).
> 2. **Belum menjalankan `seed-food`** — `pl_ingest_pihps_mysql.hpl` membaca tabel `src_tradisional_*` & `src_modern_*` di MySQL `labsource` yang dibuat oleh `seed-food`.
> 3. **Baru `git pull` tanpa rebuild & re-setup** — setelah `git pull` update repo, wajib jalankan ulang `up core` → `hop-setup` → `seed-food` agar container `workbench` dan environment Hop (`capstone-local` + `docker-local`) ter-update.
> 4. **Tidak ada koneksi internet** — `pl_ingest_bmkg.hpl` & `pl_ingest_openmeteo_live.hpl` memanggil Live REST API secara langsung.

> **Catatan volume PostgreSQL lama**: Pada clone baru, `sql/postgres-init/01-create.sql`, `02-demo.sql`, dan `03-capstone-infra.sql` (schema `curated` & role RBAC `etl_writer`/`tpid_analyst`) berjalan otomatis saat volume PostgreSQL dibuat pertama kali. Jika meng-update repo dengan volume `pg_data` lama, jalankan sekali:
> ```bash
> docker compose exec -T postgres psql -U labuser -d labdata < sql/postgres-init/03-capstone-infra.sql
> ```

---

## ⚙️ Daftar Pipeline & Workflow Apache Hop (`workspace/hop-project/`)

Pipeline dipisahkan ke subfolder per layer (`pipelines/raw/`, `pipelines/stg/`, `pipelines/dq/`, `pipelines/curated/`).

- Master workflow end-to-end **[`workflows/wf_main_etl.hwf`](workspace/hop-project/workflows/wf_main_etl.hwf)** menjalankan ingest `raw.*` (dengan *snapshot fallback* otomatis bila API live gagal setelah retry), dilanjutkan ke `stg.*`, DQ & rekonsiliasi (`dq.*`, `stg.quarantine_records`), Star Schema `curated.*`, serta logging `ops.run_manifest` & `ops.pipeline_runs`.
- Workflow ingest raw-only tetap tersedia di **[`workflows/wf_ingest_all_sources.hwf`](workspace/hop-project/workflows/wf_ingest_all_sources.hwf)**.

### Layer Raw (`pipelines/raw/`)
| File Pipeline / Workflow | Sumber (`SRC`) | Cara Ambil | Tabel Target PostgreSQL |
| :--- | :--- | :--- | :--- |
| `raw/pl_ingest_bmkg.hpl` | `SRC-08` | Live REST API BMKG (`retry 3×`) + `JsonInput` | `raw.bmkg_forecast` |
| `raw/pl_ingest_openmeteo_live.hpl` | `SRC-05..07` *(Live)* | Live REST API Open-Meteo (`retry 3×`) + `JsonInput` | `raw.openmeteo_live` |
| `raw/pl_ingest_openmeteo_archive.hpl` | `SRC-05..07` *(Arsip)* | `TextFileInput2` pada 6 CSV `cuaca *.csv` (skip 3 baris metadata) | `raw.openmeteo_archive` |
| `raw/pl_ingest_fx.hpl` | `SRC-09` | `CSVInput` (`bi_jisdor_daily.csv`) | `raw.fx_usd_idr` |
| `raw/pl_ingest_hbkn.hpl` | `SRC-13` | `CSVInput` (`ref_hbkn_calendar.csv`) | `raw.hbkn_calendar` |
| `raw/pl_ingest_info_pangan_jkt.hpl` | `SRC-04` *(Tahunan)* | `ExcelInput` (`info_pangan_jkt.xlsx`, sheet `Data`) | `raw.info_pangan_jkt` |
| `raw/pl_ingest_dki_komponen.hpl` | `SRC-04` *(Bulanan)* | `ExcelInput` (`data-harga-bahan-pokok-di-provinsi-dki-jakarta-komponen-data.xlsx`) | `raw.dki_harga_pokok_bulanan` |
| `raw/pl_ingest_pihps_mysql.hpl` | `SRC-01 & 02` | JDBC `lab-mysql` (`10` tabel `src_tradisional_*` & `src_modern_*`) | `raw.pihps_market_prices` |
| `raw/pl_ingest_pihps_produsen.hpl` | `SRC-03` | `4 CSVInput` (`beras`, `cabai_merah`, `cabai_rawit`, `bawang_merah`) *(CSV `bawang_putih` hanya punya Kalut & NTB)* | `raw.pihps_produsen_prices` |
| `raw/pl_ingest_references.hpl` | `SRC-10..12` | `3 CSVInput` (`ref_bbm_esdm.csv`, `ref_bapanas_het.csv`, `ref_supply_corridor.csv`) | `raw.ref_bbm_esdm`, `raw.ref_bapanas_het`, `raw.ref_supply_corridor` |

### Layer Staging, DQ & Curated (`pipelines/stg/`, `pipelines/dq/`, `pipelines/curated/`)
| File Pipeline | Layer | Fungsi Utama | Tabel Target PostgreSQL |
| :--- | :--- | :--- | :--- |
| `stg/pl_stg_food_prices.hpl` | Staging | Unpivot PIHPS, standarisasi komoditas/provinsi, hitung `daily_change_pct`, & bersih referensi DKI | `stg.food_prices_daily`, `stg.dki_reference_prices` |
| `stg/pl_stg_weather.hpl` | Staging | Gabung `openmeteo_archive` + `live` + agregat harian `bmkg` (filter `8888`/`9999`), hitung `rain_7d_mm` | `stg.weather_daily` |
| `stg/pl_stg_macro_ref.hpl` | Staging | Deduplikasi kurs FX harian & kalender HBKN | `stg.fx_daily`, `stg.hbkn_daily` |
| `dq/pl_dq_and_reconcile.hpl` | DQ | Eksekusi 7 aturan (`DQ-01..07`), karantina record gagal, & rekonsiliasi `raw→stg` | `stg.quarantine_records`, `dq.quality_issues`, `dq.reconciliation_log` |
| `curated/pl_load_dimensions.hpl` | Curated | Upsert idempoten 5 dimensi (termasuk `is_pre_hbkn_7d`, SCD2 HET/BBM, & FX forward-fill) | `curated.dim_*` (5 tabel) |
| `curated/pl_load_fact.hpl` | Curated | Muat fact harian, hitung MA14/margin/risk index/early alert (ketat `active_for_join`), & rekonsiliasi `stg→curated` | `curated.fact_food_supply_daily`, `dq.reconciliation_log` |
| `wf_load_sales.hwf` | Starter Lab | Workflow & pipeline baseline koneksi Postgres (`hop-demo` / `pl_load_sales.hpl`) | `stg.sales_orders` |

---

## 🖥️ Akses Aplikasi & Koneksi Database

Semua port hanya di-bind ke `127.0.0.1`:

| Aplikasi / Service | URL / Host Port | Kredensial & Keterangan |
| :--- | :--- | :--- |
| **Workbench Desktop** | [https://localhost:3001/](https://localhost:3001/) | Desktop browser XFCE (Apache Hop GUI, VSCodium, Terminal).<br>• **User**: `student` (`WEBTOP_USER` di `.env`)<br>• **Password**: cek `WEBTOP_PASSWORD` di `.env`<br>*(Terima peringatan browser self-signed SSL untuk localhost)*<br>*(Di Hop GUI, pastikan kiri bawah aktif `capstone-local` dan `docker-local`.)* |
| **CloudBeaver (SQL Client)** | [http://localhost:8978/](http://localhost:8978/) | SQL client web. Setup user admin saat pertama kali dibuka.<br>*(Data Mart tersedia di schema `curated.*`, `mart.*` [view alias], dan `semantic.v_kpi_*`.)* |
| **Grafana Dashboard** *(opsional)* | [http://localhost:3002/](http://localhost:3002/) | Jalankan dulu `bash scripts/lab.sh up observability`.<br>• **User**: `admin` \| **Password**: `GRAFANA_ADMIN_PASSWORD` di `.env`<br>• Dashboard KPI & DataOps sudah ter-provision otomatis (`Group A03 - TPID DKI Jakarta`). |
| **PostgreSQL** (`labdata`) | `127.0.0.1:55432` | User: `labuser`, Password: `POSTGRES_PASSWORD` di `.env` |
| **MySQL** (`labsource`) | `127.0.0.1:53306` | User: `labmysql`, Password: `MYSQL_APP_PASSWORD` di `.env` |

> [!TIP]
> **Setting Koneksi di CloudBeaver (`http://localhost:8978/`):**
> Karena CloudBeaver berjalan di dalam Docker network `labnet`, **jangan gunakan `localhost`**:
> - **PostgreSQL**: Host `postgres` | Port `5432` | DB `labdata` | User `labuser` | Password `POSTGRES_PASSWORD` (`.env`)
> - **MySQL**: Host `mysql` | Port `3306` | DB `labsource` | User `labmysql` | Password `MYSQL_APP_PASSWORD` (`.env`, bukan `MYSQL_ROOT_PASSWORD`)
>   - Di tab **Driver Properties**, atur **`allowPublicKeyRetrieval` = `TRUE`** dan **`useSSL` = `FALSE`** agar tidak terkena error `Public Key Retrieval is not allowed` pada MySQL 8.4.

---

## 📁 Struktur Direktori

```text
de-capstone/
├── compose.yaml                    # Konfigurasi Docker Compose (core + profil observability Grafana)
├── config/grafana/provisioning/    # Auto-provision datasource PostgreSQL & dashboard KPI Grafana
├── README.md                       # Panduan setup, pipeline, & alur kerja tim
├── SECURITY_AND_LIFECYCLE.md        # Klasifikasi data, cek secret, RBAC, & retensi (A03-26)
├── docker/                         # Dockerfile (workbench + MySQL JDBC + HOP_AUDIT_FOLDER, dll.)
├── docs/                           # Proposal, template laporan, rancangan mart, Evidence Workbook XLSX, & panduan lab
├── scripts/
│   ├── lab.sh                      # Helper script untuk Linux / macOS / Git Bash
│   └── lab.ps1                     # Helper script untuk Windows PowerShell
├── sql/
│   ├── mysql-init/01-source.sql    # DDL/seed starter MySQL labsource
│   ├── postgres-init/              # DDL/seed starter PostgreSQL + 03-capstone-infra.sql (curated & RBAC)
│   ├── 04-stg-dq-ops-ddl.sql       # DDL stg.*, stg.quarantine_records, dq.reconciliation_log, ops.run_manifest
│   ├── create_mart.sql             # DDL Star Schema curated.* (5 dim + 1 fact) & alias VIEW mart.*
│   ├── semantic_views.sql          # Views 3 KPI TPID + ringkasan DQ & Ops SLO
│   ├── mart_tests.sql              # Automated SQL mart assertions
│   └── test_rbac_and_acceptance.sql# Uji negatif RBAC tpid_analyst & 3 consumer acceptance tests
└── workspace/                      # Bind-mount ke /config/workspace di dalam Workbench
    ├── architecture/               # Kontrak desain, grain, mapping, lineage & runbook QA (DESIGN_* & RUNBOOK_*)
    ├── data/                       # 13 sumber data + SNAPSHOT_MANIFEST.md
    ├── hop-project/                # Proyek Apache Hop 2.19 (pipelines/{raw,stg,dq,curated}, workflows)
    ├── java/                       # Smoke check Java 21 (SalesCheck.java)
    └── python/                     # Script loader & fetcher per sumber (load_food_to_mysql.py, fetch_*.py)
```

---

## 🌿 Aturan Kerja Kelompok (Git Workflow)

1. **Tarik update terbaru sebelum bekerja**:
   ```bash
   git pull origin main
   ```
2. **Buat branch baru untuk setiap fitur/tugas**:
   ```bash
   git checkout -b feat/<nama-fitur>
   ```
3. **Commit dan push ke branch masing-masing** *(pastikan `.env` tidak pernah ikut ter-commit)*:
   ```bash
   git add .
   git commit -m "feat: implement data cleaning for garut weather"
   git push -u origin feat/<nama-fitur>
   ```
4. **Buka Pull Request (PR)** ke branch `main` di GitHub dan pastikan tidak ada conflict sebelum merge.

---

## 🛠️ Perintah Harian (Linux vs PowerShell)

| Tugas | Linux / Git Bash | Windows PowerShell |
| :--- | :--- | :--- |
| Cek status kontainer | `bash scripts/lab.sh status` | `.\scripts\lab.ps1 status` |
| Lihat log layanan | `bash scripts/lab.sh logs workbench` | `.\scripts\lab.ps1 logs workbench` |
| Masuk shell workbench | `bash scripts/lab.sh shell` | `.\scripts\lab.ps1 shell` |
| Registrasi ulang Hop | `bash scripts/lab.sh hop-setup` | `.\scripts\lab.ps1 hop-setup` |
| Backup PostgreSQL | `bash scripts/lab.sh backup` | `.\scripts\lab.ps1 backup` |
| Matikan layanan core | `bash scripts/lab.sh stop core` | `.\scripts\lab.ps1 stop core` |

> [!CAUTION]
> Jangan menjalankan `destroy` kecuali benar-benar ingin menghapus semua container **dan seluruh volume database**. Selalu jalankan `backup` terlebih dahulu.

Untuk inventaris versi sumber data (`D03`) lihat [SNAPSHOT_MANIFEST.md](workspace/data/SNAPSHOT_MANIFEST.md), panduan klasifikasi data & RBAC (`A03-26`) di [SECURITY_AND_LIFECYCLE.md](SECURITY_AND_LIFECYCLE.md), desain kontrak & lineage di [DESIGN_CONTRACT_LINEAGE_A03.md](workspace/architecture/DESIGN_CONTRACT_LINEAGE_A03.md), serta runbook & hasil uji QA di [RUNBOOK_AND_QA_A03.md](workspace/architecture/RUNBOOK_AND_QA_A03.md).
