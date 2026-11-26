# DOKUMENTASI BUSINESS KEY & SURROGATE KEY: DATA MART PEMANTAUAN VOLATILITAS PANGAN DAN ANOMALI IKLIM
**Proyek Capstone Data Engineering — Group A03**  
**Versi:** 1.1 (Updated & Verified with SRC-01..SRC-13 Complete Snapshot)  
**Status Dokumen:** Terverifikasi Penuh terhadap `SNAPSHOT_MANIFEST.md` dan Seluruh Dataset Aktual (`SRC-01..SRC-13`)

---

## 1. Konsep Dasar: Business Key vs. Surrogate Key

Dalam pemodelan dimensional (*Dimensional Modeling* Ralph Kimball), pengelolaan kunci identitas entitas memegang peranan krusial dalam menjamin integritas data historis, performa join, dan pelacakan perubahan data.

```
+---------------------------------------------------------------------------------------------------------+
| ASPEK              BUSINESS KEY (NATURAL KEY)                   SURROGATE KEY (DIMENSION KEY)           |
+---------------------------------------------------------------------------------------------------------+
| Sumber             Berasal langsung dari sistem operasional     Dibuat murni secara internal oleh ETL   |
|                    sumber (aplikasi hulu, API, regulasi).       Data Warehouse / Data Mart.             |
+---------------------------------------------------------------------------------------------------------+
| Tipe Data          Seringkali VARCHAR / TEXT, alphanumerik,     INTEGER / BIGINT berurutan              |
|                    atau kombinasi komposit.                     atau format tanggal YYYYMMDD.           |
+---------------------------------------------------------------------------------------------------------+
| Makna Bisnis       Memiliki makna kontekstual bagi pengguna     Tidak memiliki makna bisnis             |
|                    (misal: 'REG-01', 'garut', '2022-01-01').    (hanya penomoran urut buatan).          |
+---------------------------------------------------------------------------------------------------------+
| Penanganan SCD     TIDAK MAMPU menangani SCD Type 2 secara      MAMPU menangani SCD Type 2: satu        |
|                    mandiri karena satu entitas natural akan     business key dapat memiliki banyak      |
|                    mengalami duplikasi baris versi.             surrogate key seiring berjalannya waktu |
+---------------------------------------------------------------------------------------------------------+
| Dampak Performa    Join antar-tabel menggunakan string lambat   Join menggunakan integer cepat, memori  |
|                    dan memakan ruang index besar.               index minimal, optimasi hash join DB.   |
+---------------------------------------------------------------------------------------------------------+
```

### Mengapa Proyek Capstone Group A03 Membutuhkan Surrogate Key?
1. **Penanganan Regulasi Berubah Perlahan (SCD Type-2):**  
   Pada regulasi HET Bapanas (`ref_bapanas_het.csv`) dan tarif BBM ESDM (`ref_bbm_esdm.csv`), batas harga berubah seiring waktu berdasarkan nomor keputusan menteri/badan baru. Satu komoditas (misal: Beras Medium) memiliki 4 versi regulasi berturut-turut antara 2022–2025. Tanpa *surrogate key*, kunci natural `komoditas` tidak lagi unik. *Surrogate key* (`het_key`) menjamin setiap versi regulasi memiliki identitas unik tersendiri.
2. **Isolasi terhadap Perubahan Sistem Sumber (*Source Decoupling*):**  
   Nama komoditas pada Open Data Jakarta menggunakan format berbeda (`CABE RAWIT MERAH`, `BERAS IR. III`) dibanding PIHPS Bank Indonesia (`cabai_rawit`, `beras`). Penggunaan *surrogate key* mengisolasi data mart dari variasi penamaan sistem luar.
3. **Optimasi Indeks dan Kueri Analitik:**  
   PostgreSQL 16 memproses join multi-tabel 22 sumber jauh lebih efisien pada kolom numerik (`INT` 4-byte) dibandingkan string teks yang bervariasi panjangnya.

---

## 2. Identifikasi Seluruh Tabel Dimensi (*Dimension Tables*)

Data Mart ini mencakup **6 Tabel Dimensi Utama** dan **1 Tabel Jembatan (*Bridge Table*)**:

| Schema | Nama Tabel Dimensi | Tipe Dimensi | Entitas yang Direpresentasikan | Sumber Data Fisik Aktual |
| :--- | :--- | :--- | :--- | :--- |
| `curated` | `dim_date_hbkn` | *Conformed / Static* | Kalender harian, akhir pekan, dan hari libur keagamaan/HBKN | `ref_hbkn_calendar.csv` & deret tanggal kalender |
| `curated` | `dim_commodity` | *Conformed / Static* | Katalog 5 komoditas pangan strategis (+ komoditas pembanding) | File PIHPS (`workspace/data/food_prices/*`), Proposal Bab 2 & 3 |
| `curated` | `dim_market_tier` | *Static Lookup* | Klasifikasi tingkatan pasar (produsen, pasar tradisional, pasar modern) | Subdirektori dataset pangan, Proposal Bab 2 & 3 |
| `curated` | `dim_region` | *Conformed / Geo* | Titik wilayah sentra produksi, pasar konsumen DKI, stasiun cuaca | `bmkg_station_ref.csv`, `open_source_common.py`, file cuaca |
| `curated` | `dim_region_corridor` | *Spatial / Route* | Pasangan koridor distribusi logistik (Sentra Kabupaten $\rightarrow$ DKI Jakarta) | Proposal Bab 2 & 3, Peta Koridor Pasokan |
| `curated` | `dim_regulation_het` | *SCD Type 2* | Riwayat batas plafon HET beras dan HAP aneka cabai/bawang | `ref_bapanas_het.csv` (12 baris regulasi aktual) |
| `curated` | `dim_macro_logistics` | *SCD Type 2* | Riwayat penyesuaian harga bahan bakar logistik (Biosolar, Pertalite) | `ref_bbm_esdm.csv` (4 baris regulasi aktual) |
| `curated` | `bridge_supply_corridor` | *Bridge / Governance* | Jembatan relasional koridor komoditas–sentra–pasar serta status verifikasi & bobot pasokan | `ref_supply_corridor.csv` (`SRC-12`, 9 baris `COR-01..COR-09`) |

---

## 3. Spesifikasi Detail Business Key & Hasil Validasi Keunikan

Berikut adalah hasil profiling dan pengujian integritas langsung terhadap dataset aktual menggunakan script validasi:

### 3.1. Dimensi Tanggal & HBKN (`curated.dim_date_hbkn`)
- **Tabel Sumber:** `workspace/data/ref_hbkn_calendar.csv` digabung dengan deret kalender harian (2022-01-01 s.d. 2026-02-12).
- **Kandidat Business Key:** `full_date` (format string ISO-8601 `YYYY-MM-DD`, atau tipe data `DATE`).
- **Surrogate Key:** `date_key` (tipe `INTEGER` format `YYYYMMDD`, misal: `20220101`).
- **Contoh Nilai:**
  - `full_date`: `'2022-01-01'`, `'2023-03-23'`, `'2024-04-10'`
  - `date_key`: `20220101`, `20230323`, `20240410`
- **Hasil Validasi Keunikan Data Aktual:**
  - *Rentang waktu penuh:* 1 Januari 2022 s.d. 12 Februari 2026 = **1.504 hari kalender unik**.
  - *Pengecekan Null:* 0 null (100% lengkap).
  - *Catatan Kritis Hasil Validasi:* Dataset `ref_hbkn_calendar.csv` memiliki 147 baris dan **bukan tabel tanggal lengkap** (hanya berisi tanggal libur). Selain itu, terdapat tanggal dengan hari libur ganda:
    - `2023-03-23`: `1 Ramadan` (RAMADAN) DAN `Cuti Bersama Nyepi` (PUBLIC_HOLIDAY).
    - `2024-03-12`: `1 Ramadan` (RAMADAN) DAN `Cuti Bersama Nyepi` (PUBLIC_HOLIDAY).
  - *Aturan Pemuatan:* Dalam `dim_date_hbkn`, tanggal kalender dihasilkan lengkap (1.504 baris unik). Atribut HBKN di-join dari `ref_hbkn_calendar.csv` dengan memprioritaskan kategori HBKN mayor, sehingga `full_date` tetap **100% Unik (Kardinalitas = 1.504)**.

---

### 3.2. Dimensi Komoditas (`curated.dim_commodity`)
- **Tabel Sumber:** Folder `workspace/data/food_prices/` (nama-nama file dataset PIHPS Bank Indonesia) dan Proposal Bab 2 & 3.
- **Kandidat Business Key:** `commodity_code` (tipe `VARCHAR(32)`, huruf kecil dengan underscore).
- **Surrogate Key:** `commodity_key` (tipe `SMALLINT` / `INT`, serial: 1, 2, 3, ...).
- **Daftar Nilai Aktual Terverifikasi:**

| commodity_key | commodity_code | commodity_name | category | unit | is_strategic | is_imported |
| :---: | :--- | :--- | :--- | :--- | :---: | :---: |
| 1 | `beras` | Beras (Medium/Umum) | Serealia | kg | TRUE | FALSE |
| 2 | `cabai_rawit` | Cabai Rawit Merah | Hortikultura | kg | TRUE | FALSE |
| 3 | `cabai_merah` | Cabai Merah Keriting | Hortikultura | kg | TRUE | FALSE |
| 4 | `bawang_merah` | Bawang Merah | Hortikultura | kg | TRUE | FALSE |
| 5 | `bawang_putih` | Bawang Putih | Bumbu/Impor | kg | TRUE | TRUE |
| 6 | `daging_ayam` | Daging Ayam Ras | Peternakan | kg | FALSE | FALSE |
| 7 | `daging_sapi` | Daging Sapi | Peternakan | kg | FALSE | FALSE |
| 8 | `telur_ayam` | Telur Ayam Ras | Peternakan | kg | FALSE | FALSE |
| 9 | `minyak_goreng` | Minyak Goreng Curah/Bimoli | Olahan | kg/liter | FALSE | FALSE |
| 10 | `gula_pasir` | Gula Pasir Pasaran | Olahan | kg | FALSE | FALSE |

- **Hasil Validasi Keunikan Data Aktual:**
  - Total entitas komoditas: 10 unik.
  - 5 komoditas bertanda `is_strategic = TRUE` merupakan fokus utama pemantauan inflasi TPID DKI Jakarta sesuai proposal charter.
  - Keunikan `commodity_code`: **100% Unik, 0 Null**.

---

### 3.3. Dimensi Tingkat Pasar (`curated.dim_market_tier`)
- **Tabel Sumber:** Struktur direktori dataset pangan (`pasar_tradisional`, `pasar_modern`, `produsen`) dan skrip `load_food_to_mysql.py`.
- **Kandidat Business Key:** `market_tier_code` (tipe `VARCHAR(20)`).
- **Surrogate Key:** `market_tier_key` (tipe `SMALLINT`).
- **Daftar Nilai Aktual:**

| market_tier_key | market_tier_code | market_tier_name | description | price_type |
| :---: | :--- | :--- | :--- | :--- |
| 1 | `produsen` | Tingkat Produsen (Petani Sentra) | Harga di tingkat produsen/petani sentra pemasok | Hulu (*Farm Gate*) |
| 2 | `tradisional` | Pasar Tradisional | Harga eceran di pasar rakyat/tradisional | Hilir (*Consumer Retail*) |
| 3 | `modern` | Pasar Modern (Supermarket/Ritel) | Harga eceran di gerai ritel modern berjejaring | Hilir (*Consumer Retail*) |

- **Hasil Validasi Keunikan Data Aktual:**
  - Total entitas: 3 unik.
  - Keunikan `market_tier_code`: **100% Unik, 0 Null**.

---

### 3.4. Dimensi Wilayah Administratif & Stasiun (`curated.dim_region`)
- **Tabel Sumber:** `workspace/data/bmkg_station_ref.csv`, `workspace/python/open_source_common.py`, file arsip `workspace/data/weather/cuaca *.csv`, dan kolom provinsi PIHPS.
- **Kandidat Business Key:** 
  1. `region_key` (kode slug wilayah: `'garut'`, `'magelang'`, `'karawang'`, `'indramayu'`, `'brebes'`, `'dki_jakarta'`, `'jawa_barat'`, `'jawa_tengah'`).
  2. `adm4_code` (kode wilayah administrasi resmi Kemendagri/BPS tingkat kelurahan stasiun BMKG: misal `'32.05.01.1001'`, `'31.71.01.1001'`).
- **Surrogate Key:** `region_sk` (tipe `INT`).
- **Daftar Nilai Aktual Terverifikasi:**

| region_sk | region_key | region_name | province_name | adm4_code | latitude | longitude | role |
| :---: | :--- | :--- | :--- | :--- | :---: | :---: | :--- |
| 1 | `garut` | Kab. Garut | Jawa Barat | `32.05.01.1001` | -7.2278 | 107.9087 | SENTRA_PRODUKSI |
| 2 | `magelang` | Kab. Magelang | Jawa Tengah | `33.08.09.2001` | -7.4797 | 110.2177 | SENTRA_PRODUKSI |
| 3 | `karawang` | Kab. Karawang | Jawa Barat | `32.15.01.1001` | -6.3073 | 107.3019 | SENTRA_PRODUKSI |
| 4 | `indramayu` | Kab. Indramayu | Jawa Barat | `32.12.15.1001` | -6.3276 | 108.3249 | SENTRA_PRODUKSI |
| 5 | `brebes` | Kab. Brebes | Jawa Tengah | `33.29.09.2001` | -6.8706 | 109.0369 | SENTRA_PRODUKSI |
| 6 | `dki_jakarta` | DKI Jakarta | DKI Jakarta | `31.71.01.1001` | -6.2088 | 106.8456 | PASAR_KONSUMEN |
| 7 | `jawa_barat` | Jawa Barat (Provinsi) | Jawa Barat | `32.00.00.0000` | -6.9175 | 107.6191 | PROVINSI_AGREGAT |
| 8 | `jawa_tengah` | Jawa Tengah (Provinsi) | Jawa Tengah | `33.00.00.0000` | -7.1510 | 110.1403 | PROVINSI_AGREGAT |

- **Hasil Validasi Keunikan Data Aktual:**
  - Keunikan `region_key`: **100% Unik (8 dari 8 baris terverifikasi)**.
  - Keunikan `adm4_code` pada level stasiun cuaca: 6 kode unik pada `bmkg_station_ref.csv`.

---

### 3.5. Dimensi Koridor Pasokan (`curated.dim_region_corridor`)
- **Tabel Sumber:** Proposal Charter Bab 2 & Bab 3 (Koridor Wilayah: Pasar Konsumen DKI Jakarta $\leftarrow$ 5 Kabupaten Sentra Penyuplai Utama).
- **Kandidat Business Key:** `corridor_code` (tipe `VARCHAR(32)`, format `CRD-<SENTRA>-JKT`).
- **Surrogate Key:** `corridor_key` (tipe `INT`).
- **Daftar Nilai Aktual Terverifikasi:**

| corridor_key | corridor_code | corridor_name | origin_region_key | dest_region_key | primary_commodity_focus | transport_route |
| :---: | :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | `CRD-GARUT-JKT` | Koridor Garut – DKI Jakarta | `garut` | `dki_jakarta` | Cabai Rawit, Cabai Merah | Tol Purbaleunyi – Jakarta-Cikampek |
| 2 | `CRD-MAGELANG-JKT` | Koridor Magelang – DKI Jakarta | `magelang` | `dki_jakarta` | Cabai Rawit, Cabai Merah | Trans Jawa (Bawen-Semarang-Cipali) |
| 3 | `CRD-KARAWANG-JKT` | Koridor Karawang – DKI Jakarta | `karawang` | `dki_jakarta` | Beras | Tol Layang MBZ / Jalur Arteri Karawang |
| 4 | `CRD-INDRAMAYU-JKT` | Koridor Indramayu – DKI Jakarta | `indramayu` | `dki_jakarta` | Beras | Tol Cipali – Cikampek – Tol Lingkar Luar |
| 5 | `CRD-BREBES-JKT` | Koridor Brebes – DKI Jakarta | `brebes` | `dki_jakarta` | Bawang Merah | Tol Pejagan-Kanci – Tol Cipali |

- **Hasil Validasi Keunikan:**
  - 5 koridor terdefinisi secara baku dan mewakili seluruh jalur pasokan dalam cakupan capstone.
  - Keunikan `corridor_code`: **100% Unik**.

---

### 3.6. Dimensi Regulasi HET / HAP (`curated.dim_regulation_het` - SCD Type 2)
- **Tabel Sumber:** `workspace/data/ref_bapanas_het.csv`.
- **Kandidat Business Key (Primary Natural Key):** `reg_id` (tipe `VARCHAR(16)`, misal `'REG-01'`, `'REG-02'`).
- **Kandidat Business Key (Natural Composite Key):** `(komoditas, varian_mutu, jenis_batas, valid_from)`.
- **Surrogate Key:** `het_key` (tipe `INT`, serial).
- **Hasil Validasi Keunikan Data Aktual:**
  - Total baris: 12 baris.
  - Pengecekan keunikan `reg_id`: **12 baris unik dari 12 total baris (100% Unik, 0 null)**.
  - Pengecekan composite key `(komoditas, varian_mutu, jenis_batas, valid_from)`: **12 unik dari 12 baris (100% Unik)**.
- **Daftar Nilai Aktual Terverifikasi:**

| het_key | reg_id | komoditas | varian_mutu | jenis_batas | batas_atas_rp | dasar_regulasi | valid_from | valid_to | is_current |
| :---: | :--- | :--- | :--- | :--- | :---: | :--- | :---: | :---: | :---: |
| 1 | `REG-01` | Beras | Medium | HET Konsumen Zona 1 | 9.450 | Permendag No. 57/2017 | 2022-01-01 | 2023-03-29 | FALSE |
| 2 | `REG-02` | Beras | Medium | HET Konsumen Zona 1 | 10.900 | Perbadan No. 7/2023 | 2023-03-30 | 2024-06-04 | FALSE |
| 3 | `REG-03` | Beras | Medium | HET Konsumen Zona 1 | 12.500 | Perbadan No. 5/2024 | 2024-06-05 | 2025-08-21 | FALSE |
| 4 | `REG-04` | Beras | Medium | HET Konsumen Zona 1 | 13.500 | Kepka Bapanas 299/2025 | 2025-08-22 | 9999-12-31 | TRUE |
| 5 | `REG-05` | Beras | Premium | HET Konsumen Zona 1 | 12.800 | Permendag No. 57/2017 | 2022-01-01 | 2023-03-29 | FALSE |
| 6 | `REG-06` | Beras | Premium | HET Konsumen Zona 1 | 13.900 | Perbadan No. 7/2023 | 2023-03-30 | 2024-06-04 | FALSE |
| 7 | `REG-07` | Beras | Premium | HET Konsumen Zona 1 | 14.900 | Perbadan No. 5/2024 | 2024-06-05 | 2025-08-21 | FALSE |
| 8 | `REG-08` | Beras | Premium | HET Konsumen Zona 1 | 14.900 | Kepka Bapanas 299/2025 | 2025-08-22 | 9999-12-31 | TRUE |
| 9 | `REG-09` | Cabai Rawit Merah | Umum | HAP Konsumen | 57.000 | Perbadan No. 11/2022 | 2022-01-01 | 9999-12-31 | TRUE |
| 10 | `REG-10` | Cabai Merah Keriting | Umum | HAP Konsumen | 55.000 | Perbadan No. 11/2022 | 2022-01-01 | 9999-12-31 | TRUE |
| 11 | `REG-11` | Bawang Merah | Umum | HAP Konsumen | 41.500 | Perbadan No. 11/2022 | 2022-01-01 | 9999-12-31 | TRUE |
| 12 | `REG-12` | Bawang Putih | Umum | HAP Konsumen | 40.000 | Perbadan No. 11/2022 | 2022-01-01 | 9999-12-31 | TRUE |

---

### 3.7. Dimensi Bahan Bakar Logistik (`curated.dim_macro_logistics` - SCD Type 2)
- **Tabel Sumber:** `workspace/data/ref_bbm_esdm.csv`.
- **Kandidat Business Key (Primary Natural Key):** `bbm_id` (tipe `VARCHAR(16)`, misal `'BBM-01'`, `'BBM-02'`).
- **Kandidat Business Key (Natural Composite Key):** `(jenis_bbm, valid_from)`.
- **Surrogate Key:** `fuel_key` (tipe `INT`).
- **Hasil Validasi Keunikan Data Aktual:**
  - Total baris: 4 baris.
  - Keunikan `bbm_id`: **4 dari 4 unik (100% Unik, 0 null)**.
  - Keunikan `(jenis_bbm, valid_from)`: **4 dari 4 unik (100% Unik)**.
- **Daftar Nilai Aktual Terverifikasi:**

| fuel_key | bbm_id | jenis_bbm | kategori_bbm | harga_per_liter | dasar_regulasi | valid_from | valid_to | is_current |
| :---: | :--- | :--- | :--- | :---: | :--- | :---: | :---: | :---: |
| 1 | `BBM-01` | Biosolar | JBT (BBM Subsidi) | 5.150 | Kepmen ESDM 37.K/2022 | 2022-01-01 | 2022-09-02 | FALSE |
| 2 | `BBM-02` | Pertalite | JBKP (BBM Penugasan) | 7.650 | Kepmen ESDM 37.K/2022 | 2022-01-01 | 2022-09-02 | FALSE |
| 3 | `BBM-03` | Biosolar | JBT (BBM Subsidi) | 6.800 | Kepmen ESDM 218.K/2022 | 2022-09-03 | 9999-12-31 | TRUE |
| 4 | `BBM-04` | Pertalite | JBKP (BBM Penugasan) | 10.000 | Kepmen ESDM 218.K/2022 | 2022-09-03 | 9999-12-31 | TRUE |

---

### 3.8. Tabel Jembatan Koridor Pasokan (`curated.bridge_supply_corridor`)
- **Tabel Sumber:** `workspace/data/ref_supply_corridor.csv` (`SRC-12`, sudah tersedia fisik di workspace dan ter-ingest ke `raw.ref_supply_corridor` via `pl_ingest_references.hpl`).
- **Kandidat Business Key (Primary Natural Key):** `corridor_id` (tipe `VARCHAR(16)`, bernilai `'COR-01'` .. `'COR-09'`).
- **Kandidat Business Key (Natural Composite Key):** `(commodity_code, region_code, pasar_tujuan)` *(catatan: pada `COR-09` untuk `bawang_putih`, `region_code` bernilai `NULL` karena `origin_unresolved`)*.
- **Surrogate Key:** `bridge_id` (tipe `INT`, serial).
- **Hasil Validasi Keunikan Data Aktual:**
  - Total baris: **9 baris** (`COR-01` .. `COR-09`).
  - Keunikan `corridor_id`: **9 dari 9 unik (100% Unik, 0 Null)**.
  - Status keaktifan join (`active_for_join = TRUE`): **4 baris** (`COR-01..COR-04`, berstatus `OBSERVED_FDP` dari sampel Bapanas FDP 2024).
  - Status non-aktif (`active_for_join = FALSE`): **5 baris** (`COR-05..COR-08` berstatus `PROPOSED_UNVERIFIED`; `COR-09` berstatus `NOT_VERIFIED`).
  - Nilai `bobot_kontribusi_pasokan`: **Kosong (`NULL`) pada seluruh 9 baris** (sesuai catatan sumber: *FDP 2024 sample, NOT market-wide supply share*).
- **Temuan Crosswalk / Standardisasi Kode (MDM):**
  - `ref_supply_corridor.csv` menggunakan `cabai_rawit_merah` dan `cabai_merah_keriting`, sedangkan PIHPS (`raw.pihps_market_prices`) menggunakan `cabai_rawit` dan `cabai_merah`.
  - `ref_supply_corridor.csv` menggunakan `region_code` huruf kapital (`GARUT`, `MAGELANG`, `KARAWANG`, `INDRAMAYU`, `BREBES`), sedangkan Open-Meteo/BMKG menggunakan huruf kecil (`garut`, `magelang`, dll.). Keduanya harus dinormalisasi melalui pemetaan kanonik di lapisan staging/`mdm`.
- **Daftar Nilai Aktual Terverifikasi:**

| bridge_id | corridor_id | commodity_code | region_code | pasar_tujuan | verification_status | active_for_join | bobot_kontribusi_pasokan |
| :---: | :--- | :--- | :--- | :--- | :--- | :---: | :---: |
| 1 | `COR-01` | `cabai_rawit_merah` | `GARUT` | DKI Jakarta | `OBSERVED_FDP` | TRUE | `NULL` |
| 2 | `COR-02` | `cabai_rawit_merah` | `MAGELANG` | DKI Jakarta | `OBSERVED_FDP` | TRUE | `NULL` |
| 3 | `COR-03` | `cabai_merah_keriting` | `GARUT` | DKI Jakarta | `OBSERVED_FDP` | TRUE | `NULL` |
| 4 | `COR-04` | `cabai_merah_keriting` | `MAGELANG` | DKI Jakarta | `OBSERVED_FDP` | TRUE | `NULL` |
| 5 | `COR-05` | `beras` | `KARAWANG` | DKI Jakarta | `PROPOSED_UNVERIFIED` | FALSE | `NULL` |
| 6 | `COR-06` | `beras` | `INDRAMAYU` | DKI Jakarta | `PROPOSED_UNVERIFIED` | FALSE | `NULL` |
| 7 | `COR-07` | `bawang_merah` | `BREBES` | DKI Jakarta | `PROPOSED_UNVERIFIED` | FALSE | `NULL` |
| 8 | `COR-08` | `bawang_merah` | `GARUT` | DKI Jakarta | `PROPOSED_UNVERIFIED` | FALSE | `NULL` |
| 9 | `COR-09` | `bawang_putih` | `NULL` | DKI Jakarta | `NOT_VERIFIED` | FALSE | `NULL` |

---

## 4. Matriks Perbandingan Ringkas Business Key vs Surrogate Key

```
+------------------------+---------------------------------------------+--------------------+-------------+
| Tabel Dimensi          | Natural / Business Key                      | Surrogate Key      | Tipe Data   |
+------------------------+---------------------------------------------+--------------------+-------------+
| dim_date_hbkn          | full_date ('YYYY-MM-DD')                    | date_key           | INTEGER     |
| dim_commodity          | commodity_code ('beras', 'cabai_rawit')     | commodity_key      | SMALLINT    |
| dim_market_tier        | market_tier_code ('produsen', 'modern')     | market_tier_key    | SMALLINT    |
| dim_region             | region_key ('garut', 'dki_jakarta')         | region_sk          | INTEGER     |
| dim_region_corridor    | corridor_code ('CRD-GARUT-JKT')             | corridor_key       | INTEGER     |
| dim_regulation_het     | reg_id ('REG-01') / (komoditas, valid_from) | het_key            | INTEGER     |
| dim_macro_logistics    | bbm_id ('BBM-01') / (jenis_bbm, valid_from) | fuel_key           | INTEGER     |
| bridge_supply_corridor | corridor_id ('COR-01'..'COR-09')            | bridge_id          | INTEGER     |
+------------------------+---------------------------------------------+--------------------+-------------+
```

Seluruh kandidat business key telah tervalidasi keunikannya terhadap data aktual pada disk, menjamin tidak ada duplikasi kunci natural sebelum proses pembangkitan surrogate key di pipeline Data Mart.
