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

Project ini hanya memakai profil **Mandatory Core** (`postgres`, `mysql`, `workbench`, `cloudbeaver`) agar ringan di laptop RAM 16 GB. Ikuti langkah berikut setelah `git clone` di komputer masing-masing.

### 1. Prasyarat Sistem
- **Windows**: Docker Desktop (backend **WSL2** aktif), PowerShell 5.1+ atau Git Bash. *(Disarankan clone di path lokal seperti `C:\Projects\de-capstone`, hindari folder sync OneDrive bila memungkinkan.)*
- **Linux**: Docker Engine + Docker Compose Plugin.
- **RAM**: minimal 8–16 GB disarankan, serta internet stabil pada build pertama.

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
> File `.env` bersifat lokal/privat dan **tidak boleh di-commit** ke Git. Mengubah atau membuat ulang `.env` (misalnya saat *clone* ulang di PC yang sama) setelah volume Docker pertama kali terbuat tidak otomatis mengubah password di dalam volume `pg_data`/`mysql_data`—dan bisa memicu error `Access denied` / `password authentication failed`. Jika ingin reset bersih volume DB agar sinkron dengan `.env` baru:
> ```bash
> docker compose down
> docker volume rm de-capstone-lab_mysql_data de-capstone-lab_pg_data
> ```

### 4. Nyalakan Layanan Inti (`up core`)
Membangun dan menjalankan PostgreSQL 16, MySQL 8.4, CloudBeaver, serta Webtop Workbench (VSCodium + Apache Hop 2.19 + MySQL JDBC driver + Python + Java 21):
- **Linux / macOS / Git Bash**:
  ```bash
  bash scripts/lab.sh up core
  ```
- **Windows PowerShell**:
  ```powershell
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\lab.ps1 up core
  ```

### 5. Verifikasi, Setup Apache Hop & Muat Data Sumber
Tunggu beberapa detik setelah `up core` selesai hingga kontainer `workbench` siap, lalu jalankan secara berurutan:
- **Linux / macOS / Git Bash**:
  ```bash
  bash scripts/lab.sh preflight
  bash scripts/lab.sh hop-demo     # Registrasi project Hop (capstone-local) + uji pipeline baseline (60 baris)
  bash scripts/lab.sh seed-food    # Muat 17 tabel harga pangan ke MySQL labsource
  # Jalankan master workflow Apache Hop untuk ingest semua sumber yang tersedia -> PostgreSQL raw.*:
  docker compose exec -T -u abc workbench bash -lc 'cd /opt/hop && ./hop-run.sh -j capstone-local -e docker-local -r local -f /config/workspace/hop-project/workflows/wf_ingest_all_sources.hwf'
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
  docker compose exec -T -u abc workbench bash -lc "cd /opt/hop && ./hop-run.sh -j capstone-local -e docker-local -r local -f /config/workspace/hop-project/workflows/wf_ingest_all_sources.hwf"
  # Opsional: segarkan snapshot CSV API (Open-Meteo, BMKG, USD/IDR, HBKN)
  docker compose exec -T -u abc workbench python /config/workspace/python/fetch_openmeteo_weather.py
  docker compose exec -T -u abc workbench python /config/workspace/python/fetch_bmkg_forecast.py
  docker compose exec -T -u abc workbench python /config/workspace/python/fetch_fx_usd_idr.py
  docker compose exec -T -u abc workbench python /config/workspace/python/fetch_hbkn_holidays.py
  ```
> **Pipeline Hop yang sudah tersedia (`wf_ingest_all_sources.hwf`):**
> - `pl_ingest_pihps_mysql.hpl` (`SRC-01..02`, MySQL `labsource`) → `raw.pihps_market_prices`
> - `pl_ingest_pihps_produsen.hpl` (`SRC-03`, CSV produsen Jabar/Jateng) → `raw.pihps_produsen_prices` *(CSV produsen `bawang_putih` hanya memiliki kolom Kalut & NTB)*
> - `pl_ingest_info_pangan_jkt.hpl` (`SRC-04`, `info_pangan_jkt.xlsx`) → `raw.info_pangan_jkt`
> - `pl_ingest_openmeteo_archive.hpl` & `pl_ingest_openmeteo_live.hpl` (`SRC-05..07`) → `raw.openmeteo_archive`, `raw.openmeteo_live`
> - `pl_ingest_bmkg.hpl` (`SRC-08`, Live API BMKG) → `raw.bmkg_forecast`
> - `pl_ingest_fx.hpl` (`SRC-09`, `bi_jisdor_daily.csv`) → `raw.fx_usd_idr`
> - `pl_ingest_hbkn.hpl` (`SRC-13`, `ref_hbkn_calendar.csv`) → `raw.hbkn_calendar`
>
> **Catatan volume lama**: Pada clone baru, `sql/postgres-init/01-create.sql`, `02-demo.sql`, dan `03-capstone-infra.sql` (schema `curated` & role RBAC `etl_writer`/`tpid_analyst`) berjalan otomatis saat volume PostgreSQL dibuat pertama kali. Jika Anda meng-update repo dengan volume `pg_data` yang sudah terlanjur ada, jalankan sekali:
> ```bash
> docker compose exec -T postgres psql -U labuser -d labdata < sql/postgres-init/03-capstone-infra.sql
> ```

---

## 🖥️ Akses Aplikasi & Koneksi Database

Semua port hanya di-bind ke `127.0.0.1`:

| Aplikasi / Service | URL / Host Port | Kredensial & Keterangan |
| :--- | :--- | :--- |
| **Workbench Desktop** | [https://localhost:3001/](https://localhost:3001/) | Desktop browser XFCE (Apache Hop GUI, VSCodium, Terminal).<br>• **User**: `student` (`WEBTOP_USER` di `.env`)<br>• **Password**: cek `WEBTOP_PASSWORD` di `.env`<br>*(Terima peringatan browser self-signed SSL untuk localhost)* |
| **CloudBeaver (SQL Client)** | [http://localhost:8978/](http://localhost:8978/) | SQL client web. Setup user admin saat pertama kali dibuka. |
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
├── AGENTS.md                       # AI context & aturan engineering repo
├── compose.yaml                    # Konfigurasi Docker Compose (core + profil opsional)
├── docker/                         # Dockerfile (workbench + MySQL JDBC, airflow, flink, spark, superset)
├── docs/                           # Proposal, template laporan, workbook, panduan lab, & arsip dataset
├── scripts/
│   ├── lab.sh                      # Helper script untuk Linux / macOS / Git Bash
│   └── lab.ps1                     # Helper script untuk Windows PowerShell
├── sql/
│   ├── mysql-init/01-source.sql    # DDL/seed starter MySQL labsource
│   └── postgres-init/              # DDL/seed starter PostgreSQL + 03-capstone-infra.sql (curated & RBAC)
└── workspace/                      # Bind-mount ke /config/workspace di dalam Workbench
    ├── data/                       # Dataset pangan, cuaca Open-Meteo, snapshot BMKG, kurs USD/IDR, HBKN
    ├── hop-project/                # Proyek Apache Hop 2.19 (environments, metadata, pipelines, workflows)
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
