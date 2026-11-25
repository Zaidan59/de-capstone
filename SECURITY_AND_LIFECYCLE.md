# Security & Data Lifecycle — Capstone Group A03

Dokumen ini menjadi acuan kontrol keamanan repositori, klasifikasi data, privasi/minimization, dan siklus hidup (retensi & penghapusan) data pada proyek *Governed Data Mart Volatilitas Harga Pangan & Anomali Iklim DKI Jakarta*.

---

## 1. Klasifikasi Data & Penggunaan Sampel Sintetis

| Kategori | Sumber / Tabel | Sifat & Batasan |
| :--- | :--- | :--- |
| **`PUBLIC_OPEN`** | `SRC-01..03` (PIHPS BI), `SRC-04` (Info Pangan / Harga Pokok DKI), `SRC-05..07` (Open-Meteo ERA5 & Live), `SRC-08` (BMKG), `SRC-09` (Kurs USD/IDR), `SRC-13` (Kalender Libur & HBKN) | Data terbuka publik/akademik; **bebas PII**, tanpa identitas perorangan, nomor telepon, atau alamat rumah. |
| **`PUBLIC_REGULATION`** | `SRC-10` (`ref_bbm_esdm.csv`), `SRC-11` (`ref_bapanas_het.csv`) | Data regulasi publik resmi (Kepmen ESDM, Permendag, Perbadan/Kepka Bapanas) berstruktur SCD Type-2. |
| **`PROJECT_ASSUMPTION`** | `SRC-12` (`ref_supply_corridor.csv`) | Memisahkan koridor teramati (`OBSERVED_FDP`, `active_for_join=TRUE`) vs koridor usulan proyek (`PROPOSED_UNVERIFIED` / `NOT_VERIFIED`, `active_for_join=FALSE`); kolom bobot tidak diisi angka fiktif. |
| **`SYNTHETIC_DEMO`** | `sql/mysql-init/01-source.sql` (`demo_customers`, `demo_orders`), `sql/postgres-init/02-demo.sql` (`raw.sales_orders`, `mart.daily_sales`) | Hanya dipakai untuk bootstrap & uji konektivitas (`lab.sh preflight` / `hop-demo`); ditandai `"Synthetic bootstrap, not a real production run"` di `ops.pipeline_runs` dan **tidak dicampur** ke `curated.*`. Dataset sintetis non-proyek (`ocs_assets_synthetic.csv`, `zabbix_trends_synthetic.csv`, `sales_events.jsonl`) sudah dihapus dari `workspace/data/`. |

---

## 2. Data Minimization, Masking & Kontrol Akses (RBAC)

- **Minimization**: Hanya kolom analitik yang dibutuhkan KPI yang ditarik (`tanggal`, `wilayah`/`kode_adm4`, `komoditas`, `harga`, `cuaca`, `kurs`, `regulasi`). Tidak ada pengambilan/penyimpanan kredensial pengguna, token API, IP host internal, atau serial perangkat.
- **Least-Privilege RBAC** (`sql/postgres-init/03-capstone-infra.sql`):
  - **`etl_writer`**: hak baca/tulis pada `raw`, `stg`, `dq`, `ops`, `mart`, `mdm`, `curated`, `semantic` (khusus proses pipeline ETL).
  - **`tpid_analyst`**: hak **read-only (`SELECT`) hanya pada schema `curated` dan `semantic`** (tidak memiliki akses ke `raw`, `stg`, `dq`, `ops`, maupun operasi `INSERT`/`UPDATE`/`DELETE`).
- **Hasil Uji RBAC (PostgreSQL `labdata`)**:
  - Positif (`SET LOCAL ROLE tpid_analyst; SELECT COUNT(*) FROM semantic.v_daily_sales;`) → **berhasil (`6` baris)**.
  - Negatif (`SET LOCAL ROLE tpid_analyst; SELECT COUNT(*) FROM raw.bmkg_forecast;`) → **ditolak (`ERROR: permission denied for schema raw`)**.

---

## 3. Pengaturan Environment Variables & Lokasi File Aman

- **Pemisahan Secret**: Seluruh kredensial lokal (`POSTGRES_PASSWORD`, `MYSQL_ROOT_PASSWORD`, `MYSQL_APP_PASSWORD`, `WEBTOP_PASSWORD`, dll.) hanya disimpan di file `.env` pada mesin lokal dan **wajib diabaikan oleh `.gitignore`** (`.env.example` hanya berisi placeholder `__GENERATE__`).
- **Injeksi Kredensial Apache Hop**: Pipeline `.hpl`/`.hwf` dan metadata koneksi (`lab-postgres.json`, `lab-mysql.json`) hanya menyimpan referensi variabel `${LAB_DB_*}` dan `${LAB_MYSQL_*}`. Nilai password disuntik saat runtime oleh `docker/workbench/hop-setup` ke `/config/hop-config/docker-secrets.json` di dalam volume container `workbench_config` (tidak pernah di-commit ke Git).
- **Pembatasan Jaringan**: Seluruh port layanan pada `compose.yaml` terikat ketat ke **`127.0.0.1`** (tidak dibuka ke `0.0.0.0`).
- **Lokasi Penyimpanan Aman**: Hindari menaruh `.env` dan Docker DB volumes di dalam folder *cloud-sync* (seperti OneDrive) untuk mencegah konflik *file-locking* dan kebocoran sinkronisasi kredensial.

---

## 4. Aturan Retensi & Penghapusan Data (*Lifecycle*)

| Layer / Artefak | Kebijakan Retensi | Mekanisme Pembersihan / Penghapusan |
| :--- | :--- | :--- |
| **`raw.*`** (12 tabel sumber) | Arsip historis (`2022–2026`) & snapshot API terbaru disimpan sepanjang semester proyek. | Snapshot harian/referensi di-refresh secara idempoten (`truncate=Y` pada eksekusi pipeline). |
| **`stg.*` & `stg.quarantine_*`** | Disimpan sepanjang siklus proyek untuk pelacakan pembersihan & resolusi anomali DQ. | Dikelola per `run_id`; dibersihkan/diarsipkan setelah evaluasi akhir mata kuliah. |
| **`dq.quality_issues`, `ops.pipeline_runs`, `ops.pipeline_watermarks`** | Disimpan sepanjang proyek sebagai *audit trail* kualitas data, eksekusi, dan pemulihan. | Diekspor ke artefak bukti sebelum penutupan environment lab. |
| **`curated.*` & `semantic.*`** | Disimpan sebagai model analitik final selama periode demo & penilaian UAS. | Divalidasi lewat query KPI dan *acceptance tests*, tidak menyimpan data terbatas/PII. |
| **Backup Lokal (`backups/`)** | Backup SQL PostgreSQL (`bash scripts/lab.sh backup`) bersifat lokal dan tidak di-commit ke Git bila memuat dump operasional. | Hapus dump lama secara berkala; penghapusan total container + seluruh volume dilakukan via `bash scripts/lab.sh destroy` (dengan konfirmasi `DELETE`). |

---

## 5. Checklist Verifikasi Keamanan Repositori

- [x] `git ls-files .env` kosong (`.env` tidak ter-track di Git).
- [x] Tidak ada nilai password/secret dari `.env` yang muncul di file tracked (`compose.yaml`, `*.hpl`, `*.hwf`, `*.json`, `*.py`, `*.sql`, `*.md`).
- [x] Seluruh port pada `compose.yaml` terikat ke `127.0.0.1:` (tidak ada `0.0.0.0:`).
- [x] Sampel sintetis membingungkan (`ocs_assets_synthetic.csv`, `zabbix_trends_synthetic.csv`, `sales_events.jsonl`) sudah dihapus dari `workspace/data/`.
- [x] Uji RBAC negatif mengonfirmasi `tpid_analyst` ditolak mengakses schema `raw`.
