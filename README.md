# Paket Infrastruktur Proyek Akhir Data Engineering (S1 Sistem Informasi)

**Edisi 2026 — Windows (PowerShell/Git Bash) dan Linux — Docker Compose**

Paket **infrastruktur saja**, terpisah dari Project Proposal, Final Report,
Data & Evidence Workbook, serta rubrik dosen. Tidak perlu hasil praktikum
pertemuan 05–14 untuk memulai. **Belum termasuk image Docker/offline mirror**:
Docker akan menarik image/build dependencies dari internet pada eksekusi awal.

## Mulai cepat

1. Pasang Docker Desktop + WSL2 (Windows) atau Docker Engine + Compose Plugin (Linux).
2. Ekstrak ZIP ke direktori biasa (hindari OneDrive/network drive dan path panjang/spasi ekstrem).
3. Dari PowerShell:
   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\lab.ps1 init
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\lab.ps1 up core
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\lab.ps1 preflight
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\lab.ps1 hop-demo
   ```
4. Dari Git Bash atau Linux:
   ```bash
   bash scripts/lab.sh init
   bash scripts/lab.sh up core
   bash scripts/lab.sh preflight
   bash scripts/lab.sh hop-demo
   ```
5. Buka aplikasi:

   | Aplikasi | URL | Keterangan |
   | --- | --- | --- |
   | **Workbench** | **https://localhost:3001/** | XFCE browser desktop dengan **VSCodium desktop sungguhan**, Apache Hop GUI, Python, Java 21, Maven, Git |
   | **CloudBeaver** | http://localhost:8978/ | **DBeaver Web (CloudBeaver Community)**, SQL client berbasis browser |
   | PostgreSQL | localhost:55432 | DB `labdata`, user `labuser`, password di `.env` |
   | MySQL | localhost:53306 | DB `labsource`, user `labmysql`, password di `.env` |

   Browser akan memperingatkan sertifikat HTTPS self-signed Workbench.
   Lanjutkan hanya untuk `localhost` pada PC Anda. Login Workbench memakai
   `WEBTOP_USER` dan `WEBTOP_PASSWORD` dari `.env`.

**Jangan** mengekspos port Workbench ke Internet: terminal desktop Webtop
memberikan hak menjalankan perintah di container. Semua host port dalam
Compose diikat ke `127.0.0.1` secara default.

## Layanan wajib dan opsional

| Jenis | Layanan | Profile/perintah | Fungsi |
| --- | --- | --- | --- |
| **Core** | PostgreSQL 16 | `up core` | Analytics, metadata operasional, data-quality samples |
| **Core** | MySQL 8.4 | `up core` | Contoh transactional source |
| **Core** | Apache Hop 2.19 GUI + CLI | Di Workbench | ETL/ELT workflow, pipelines |
| **Core** | VSCodium, Python, Java 21, Maven, Git | Di Workbench | Development Python/Java, editor kode |
| **Core** | CloudBeaver Community | `up core` | DBeaver dalam browser, JDBC query |
| Optional | Airflow 3 | `up orchestration` | Scheduling, retries/backfill; Hop runtime tersedia |
| Optional | Kafka + Flink SQL | `up streaming` | Event delivery, stateful/event-time analysis |
| Optional | Spark + Iceberg | `up lakehouse` | Snapshots, schema evolution, time travel |
| Optional | MinIO | `up objectstore` | Storage kompatibel S3 untuk eksperimen |
| Optional | OpenMetadata | `up metadata` | Catalog, glossary, lineage; deployment berat/eksperimental |
| Optional | Grafana | `up observability` | Dashboard PostgreSQL metrics |
| Optional | Apache Superset | `up bi` | Consumer dashboards, BI |
| Optional | Keycloak | `up identity` | SSO/IAM extension; bukan kebutuhan wajib capstone |

Lihat `docs/SERVICE_MATRIX.md` dan `docs/CROSS_PLATFORM_GUIDE.md`.

## Menggunakan Apache Hop + VSCodium

1. Buka Workbench di `https://localhost:3001`.
2. Menu XFCE **Applications → Development → Apache Hop GUI**, atau buka terminal dan jalankan `hop-gui`.
3. Jalankan `hop-setup` satu kali (atau `./scripts/lab.sh hop-setup` dari host).
4. Proyek tersedia di `/config/workspace/hop-project`.
5. Metadata connection `lab-postgres` merujuk ke variabel `LAB_DB_HOST`, dst.,
   bukan password plaintext. Pipeline demo `pl_load_sales.hpl` membaca
   `raw.sales_orders`, mengisi ulang `stg.sales_orders` (khusus data sintetis).
6. Jalankan Workbench editor **VSCodium** dari menu, dan buka folder
   `/config/workspace` untuk menulis Python dan Java.
7. Uji `python /config/workspace/python/extract_sales.py` serta:
   ```bash
   cd /config/workspace/java
   javac SalesCheck.java && java SalesCheck
   ```

`hop-demo` hanya mereset tabel staging **data sintetis**; jangan memakainya
pada data asli. Docker Compose core menyiapkan data demo otomatis pada
inisialisasi database yang pertama.

## Koneksi CloudBeaver

Pada first-run wizard buat administrator CloudBeaver lokal. Tambahkan:

- PostgreSQL: **host `postgres`**, port `5432`, database `labdata`, user `labuser`.
- MySQL: **host `mysql`**, port `3306`, database `labsource`, user `labmysql`.

Jangan memasukkan `localhost` sebagai host DB dari dalam CloudBeaver:
`localhost` di sana berarti container CloudBeaver, bukan PC Windows/Linux.

## Privasi dan integrasi LABFIK

File `workspace/data/` adalah **data sintetis**, bukan export produksi Zabbix 7
atau OCS Inventory 3. Adapter Python contoh ditempatkan di `workspace/python/`
dan tidak akan mengakses server sampai URL/token read-only disediakan sendiri.
Akses nyata wajib disetujui data owner dengan scope, rate limit, klasifikasi,
retention, serta audit trail. Jangan menyimpan credential production di Git/ZIP.

## Pengendalian resource dan data

- **Core**: disarankan RAM host 16 GB (12 GB bisa terbatas); internet diperlukan untuk build Hop/VSCodium.
- **Streaming/Lakehouse**: disarankan RAM host 24–32 GB atau jalankan pada VM bersama.
- **OpenMetadata**: disarankan RAM host 24–32 GB dan 4+ vCPU; harus ditest terpisah terlebih dahulu.
- `stop` mempertahankan volume dan workspace.
- `backup` menghasilkan `backups/labdata_*.sql`.
- `reset-demo` hanya reset tabel contoh, tidak menghapus workspaces/volume.
- `destroy` **menghapus semua named volumes** dan harus mengetik `DELETE`.

## Batas validasi

File paket, JSON/XML, YAML dan shell scripts telah diperiksa secara statis.
**Docker image build dan integrasi runtime belum dapat diuji pada lingkungan
pembuatan dokumen ini.** Instruktur/kelompok wajib menjalankan checklist pada
`docs/BEFORE_CLASS_AND_QA.md` di PC target sebelum menyatakan siap kelas.
Profile OpenMetadata adalah **opt-in experimental**, bukan instalasi production.
