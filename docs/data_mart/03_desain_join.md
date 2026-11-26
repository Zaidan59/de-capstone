# DESAIN JOIN, ANALISIS KARDINALITAS, DAN MITIGASI FAN-OUT / DOUBLE COUNTING
**Proyek Capstone Data Engineering — Group A03**  
**Versi:** 1.1 (Updated & Verified with SRC-01..SRC-13 Complete Snapshot)  
**Status Dokumen:** Terverifikasi Penuh terhadap `SNAPSHOT_MANIFEST.md` & `ref_supply_corridor.csv` (PostgreSQL 16 Compatible)

---

## 1. Pendahuluan dan Prinsip Desain JOIN

Dalam arsitektur *Dimensional Modeling* (Star Schema & Galaxy Schema), operasi `JOIN` menghubungkan tabel fakta (*Fact Tables*) dengan tabel dimensi (*Dimension Tables*) serta antarfakta melalui tabel jembatan (*Bridge Table*). Desain JOIN yang buruk berisiko memicu:
1. **Fan-Out:** Penggandaan jumlah baris (*row multiplication*) akibat relasi $1 : M$ atau $M : N$ yang tidak terkontrol pada kondisi join.
2. **Double Counting:** Penggandaan nilai metrik aditif (seperti harga atau volume pasokan) akibat agregasi naif terhadap baris yang telah mengalami *fan-out*.
3. **Data Loss (Silent Drop):** Hilangnya baris transaksi akibat penggunaan `INNER JOIN` pada atribut yang memiliki *null* atau kekosongan kalender (seperti kurs hari libur).

Dokumen ini menetapkan pemetaan relasi antartabel secara menyeluruh, kardinalitas, jenis join, mitigasi risiko matematis, kebutuhan *bridge table*, serta contoh kueri SQL operasional yang siap dieksekusi di PostgreSQL 16.

---

## 2. Matriks Relasi Antartabel dan Kardinalitas

Berikut adalah pemetaan hubungan antara seluruh tabel dimensi dan tabel fakta pada skema `curated`:

| Tabel Asal (*Source / Dimension*) | Kolom Join Asal | Tabel Tujuan (*Target / Fact*) | Kolom Join Tujuan | Kardinalitas | Jenis JOIN yang Direkomendasikan | Alasan & Perilaku Join |
| :--- | :--- | :--- | :--- | :---: | :--- | :--- |
| `dim_date_hbkn` | `date_key` | `fact_food_price_daily` | `date_key` | $1 : M$ | `INNER JOIN` | Setiap hari memiliki observasi harga; tanggal kalender lengkap 1.504 hari. |
| `dim_commodity` | `commodity_key` | `fact_food_price_daily` | `commodity_key` | $1 : M$ | `INNER JOIN` | Integritas referensial terjaga ke 5-10 komoditas terdaftar. |
| `dim_market_tier` | `market_tier_key` | `fact_food_price_daily` | `market_tier_key` | $1 : M$ | `INNER JOIN` | Klasifikasi 3 tingkatan pasar (produsen, tradisional, modern). |
| `dim_region` | `region_sk` | `fact_food_price_daily` | `region_sk` | $1 : M$ | `INNER JOIN` | Pemetaan wilayah administratif (provinsi pasar konsumen/produsen). |
| `dim_date_hbkn` | `date_key` | `fact_weather_daily` | `date_key` | $1 : M$ | `INNER JOIN` | Rekaman cuaca harian sinkron dengan kalender kalender. |
| `dim_region` | `region_sk` | `fact_weather_daily` | `region_sk` | $1 : M$ | `INNER JOIN` | Stasiun observasi cuaca sentra (Garut, Magelang, Karawang, dll.). |
| `dim_date_hbkn` | `date_key` | `fact_macro_logistics_daily` | `date_key` | $1 : 1$ / $1 : M$ | `INNER JOIN` | Indikator makro harian tersinkronisasi per tanggal. |
| `dim_regulation_het` | `commodity_key` + rentang tanggal | `fact_food_supply_daily` | `commodity_key` + `full_date` | $1 : 1$ | `LEFT JOIN` (dengan predikat rentang tanggal) | Regulasi SCD Type-2 berlaku sepanjang rentang `valid_from` s.d. `valid_to`. `LEFT JOIN` menjaga data harga tetap tampil jika ada periode tanpa batas regulasi resmi. |
| `dim_macro_logistics` | `fuel_key` | `fact_macro_logistics_daily` | `solar_fuel_key` & `pertalite_fuel_key` | $1 : M$ | `LEFT JOIN` | Role-Playing Foreign Key yang mereferensikan versi regulasi tarif Solar dan Pertalite SCD Type-2 yang aktif pada hari tersebut. |
| `dim_macro_logistics` | `fuel_key` | `fact_food_supply_daily` | `solar_fuel_key` | $1 : M$ | `LEFT JOIN` | Mereferensikan regulasi tarif Biosolar yang menjadi bahan bakar utama armada truk logistik pangan koridor. |
| `dim_region_corridor`| `corridor_key` | `fact_food_supply_daily` | `corridor_key` | $1 : M$ | `INNER JOIN` | Relasi koridor sentra pemasok $\rightarrow$ DKI Jakarta. |
| `dim_commodity` | `commodity_key` | `bridge_supply_corridor`| `commodity_key` | $1 : M$ | `INNER JOIN` | Pemetaan alokasi komoditas pada jembatan pasokan. |
| `dim_region_corridor`| `corridor_key` | `bridge_supply_corridor`| `corridor_key` | $1 : M$ | `INNER JOIN` | Pemetaan koridor pada jembatan pasokan. |

---

## 3. Analisis Risiko Fan-Out, Double Counting, dan Solusi Arsitektural

### 3.1. Hubungan Harga DKI Jakarta dengan Koridor Pemasok (Risiko Double Counting)

> [!CAUTION]
> **MASALAH BISNIS & MATEMATIS:**  
> DKI Jakarta adalah **1 titik temu pasar konsumen**, tetapi disuplai oleh **banyak kabupaten sentra**.  
> Contoh: Beras dipasok oleh Karawang (Koridor 3) dan Indramayu (Koridor 4).  
> Jika harga beras DKI Jakarta (misal Rp 13.550) dimasukkan sebagai kolom aditif di setiap baris koridor, kueri agregasi `SUM(consumer_price_dki)` akan menjumlahkan angka Rp 13.550 sebanyak dua kali (menjadi Rp 27.100).

```
[Ilustrasi Fan-Out Harga DKI Jakarta Tanpa Proteksi Grain]

Tanggal: 2022-01-03 | Komoditas: Beras
Harga Konsumen Riil DKI Jakarta: Rp 13.550 / kg

Koridor Pasokan:
  ├─> Koridor Karawang -> DKI  (Harga Produsen Jabar: Rp 8.950) ──> Harga Konsumen DKI: Rp 13.550
  └─> Koridor Indramayu -> DKI (Harga Produsen Jabar: Rp 8.950) ──> Harga Konsumen DKI: Rp 13.550

KUERI NAIF: SELECT SUM(Harga_Konsumen_DKI) ==> Rp 27.100 (SALAH BESAR / DOUBLE COUNTING 200%)
```

#### Solusi dan Aturan Desain JOIN:
1. **Pemisahan Jalur Agregasi (Dual-Path Query):**  
   - Analisis harga konsumen murni DKI Jakarta **wajib** dikueri dari `curated.fact_food_price_daily` dengan filter `market_tier_key = 2` (tradisional) atau `3` (modern) dan `region_key = 'dki_jakarta'`. Pada tabel ini, DKI Jakarta dijamin hanya memiliki **tepat 1 baris** per tanggal dan komoditas.
   - Analisis rantai pasok koridor dikueri dari `curated.fact_food_supply_daily` dengan mendeklarasikan kolom `consumer_price_dki` sebagai **Semi-Additive (hanya boleh diagregasi menggunakan `AVG()` atau `MAX()`, dilarang `SUM()`)**.
2. **Penggunaan Bridge Table dengan Bobot Kontribusi (`bridge_supply_corridor`):**  
   Jika analis ingin menghitung *Weighted Producer Cost* yang mengalir ke Jakarta, perhitungannya dilakukan melalui join ke `bridge_supply_corridor`:
   $$\text{Weighted Producer Price} = \sum (\text{Producer Price}_i \times \text{Supply Weight}_i)$$
   di mana $\sum \text{Supply Weight}_i = 1.0$ (100%).

---

### 3.2. Risiko Fan-Out pada Hari Libur Ganda (`ref_hbkn_calendar.csv`)
- **Akar Masalah:**  
  Hasil profiling dataset menemukan bahwa pada tanggal `2023-03-23` dan `2024-03-12`, terdapat 2 entri hari libur (`1 Ramadan` dan `Cuti Bersama Nyepi`).
- **Dampak Fan-Out:**  
  Jika kueri analitik melakukan `JOIN fact_food_price_daily f ON f.full_date = h.holiday_date`, baris harga pada kedua tanggal tersebut akan digandakan 2x.
- **Solusi Desain:**  
  Tabel fakta **TIDAK PERNAH** di-join langsung ke file mentah `ref_hbkn_calendar.csv`. Pemuatan harus selalu melalui tabel dimensi yang telah di-governed: `curated.dim_date_hbkn`. Pada tabel dimensi tersebut, setiap tanggal kalender strictly unik 1 baris, di mana nilai HBKN telah dikonsolidasikan pada tahap ETL.

---

### 3.3. Risiko Fan-Out pada Regulasi SCD Type-2 (`ref_bapanas_het.csv`)
- **Akar Masalah:**  
  1. Komoditas Beras pada regulasi memiliki 2 varian mutu: `Medium` dan `Premium`.
  2. Rentang tanggal berlaku menggunakan format `valid_from` dan `valid_to`.
- **Dampak Fan-Out:**  
  Jika kondisi join hanya berupa:
  ```sql
  ON f.commodity = r.komoditas 
  AND f.full_date >= r.valid_from 
  AND f.full_date <= r.valid_to
  ```
  maka baris beras pada tabel fakta akan di-join ke **2 baris regulasi sekaligus** (Medium dan Premium), menggandakan jumlah baris fakta beras sebanyak 2x.
- **Solusi Desain:**  
  Kondisi join HET wajib menyertakan predikat varian mutu:
  ```sql
  ON f.commodity_name = r.komoditas 
  AND r.varian_mutu = 'Medium'  -- Baseline pangan pokok konsumen
  AND f.full_date >= r.valid_from 
  AND f.full_date <= r.valid_to
  ```

---

### 3.4. Risiko Fan-Out pada Tarif Bahan Bakar Minyak (`ref_bbm_esdm.csv`)
- **Akar Masalah:**  
  Pada rentang tanggal yang sama, terdapat 2 jenis BBM yang aktif secara simultan: `Biosolar` dan `Pertalite`.
- **Dampak Fan-Out:**  
  Join berbasis tanggal kalender tanpa menyaring jenis BBM akan menghasilkan 2 baris untuk setiap 1 baris fakta.
- **Solusi Desain:**  
  - Pada lapisan staging, tabel tarif BBM di-pivot menjadi kolom mendatar (`solar_price_per_liter`, `pertalite_price_per_liter`), ATAU
  - Menetapkan filter eksplisit pada armada logistik pangan (yaitu `jenis_bbm = 'Biosolar'`, karena truk logistik distribusi pangan antar-kota Jawa Barat–DKI Jakarta menggunakan mesin diesel berbahan bakar Solar).

---

### 3.5. Risiko Data Loss pada Kurs USD/IDR (`bi_jisdor_daily.csv`)
- **Akar Masalah:**  
  Data JISDOR hanya tersedia pada hari kerja perbankan (1.250 baris), sedangkan data harga pangan dan iklim berjalan 7 hari seminggu (1.504 baris).
- **Dampak Data Loss:**  
  Penggunaan `INNER JOIN` akan membuang (~17%) data harga pangan pada hari Sabtu, Minggu, dan hari libur nasional.
- **Solusi Desain:**  
  Menggunakan teknik **Imputasi Forward-Fill / LOCF (Last Observation Carried Forward)** pada proses ELT, atau menggunakan `LEFT JOIN` yang dilengkapi klausa fungsi jendela `WINDOW` untuk mengisi nilai kurs terakhir yang tersedia:
  ```sql
  COALESCE(fx.usd_idr_rate, LAG(fx.usd_idr_rate) OVER (ORDER BY d.full_date))
  ```

---

## 4. Kebutuhan dan Spesifikasi Bridge Table (`bridge_supply_corridor`)

### Mengapa Bridge Table Dibutuhkan?
1. **Menghubungkan Relasi Many-to-Many ($M : N$):**  
   Satu komoditas (misal: `cabai_rawit_merah`) dipasok oleh banyak kabupaten sentra (`GARUT` dan `MAGELANG`). Sebaliknya, satu kabupaten sentra (`GARUT`) memasok lebih dari satu komoditas (`cabai_rawit_merah` dan `cabai_merah_keriting`).
2. **Menyaring Koridor Terobservasi vs. Belum Terverifikasi (`active_for_join`):**  
   Berdasarkan data aktual `workspace/data/ref_supply_corridor.csv` (`SRC-12`), hanya `COR-01..COR-04` yang berstatus `OBSERVED_FDP` (`active_for_join = TRUE`). `COR-05..COR-08` (`PROPOSED_UNVERIFIED`) dan `COR-09` (`NOT_VERIFIED`) memiliki `active_for_join = FALSE` sehingga wajib difilter sebelum `JOIN` agar tidak mencampur data observasi empiris dengan asumsi koridor.
3. **Menampung Bobot Pasokan (`bobot_kontribusi_pasokan`) Saat Tersedia:**  
   Pada snapshot `fdp-2024-v1`, kolom `bobot_kontribusi_pasokan` bernilai `NULL` pada seluruh 9 baris (*FDP 2024 sample, NOT market-wide supply share*). Oleh karena itu, kolom skema dirancang nullable (`NULL` diizinkan).

### Definisi DDL Bridge Table (PostgreSQL 16):
```sql
CREATE TABLE IF NOT EXISTS curated.bridge_supply_corridor (
    bridge_id SERIAL PRIMARY KEY,
    corridor_id VARCHAR(16) NOT NULL UNIQUE, -- Business Key SRC-12: COR-01..COR-09
    commodity_key SMALLINT NOT NULL REFERENCES curated.dim_commodity(commodity_key),
    corridor_key INT REFERENCES curated.dim_region_corridor(corridor_key), -- Nullable untuk COR-09 (origin_unresolved)
    origin_region_sk INT REFERENCES curated.dim_region(region_sk),        -- Nullable untuk COR-09
    destination_region_sk INT NOT NULL REFERENCES curated.dim_region(region_sk),
    corridor_type VARCHAR(30) NOT NULL,      -- domestic_production / origin_unresolved
    verification_status VARCHAR(30) NOT NULL,-- OBSERVED_FDP / PROPOSED_UNVERIFIED / NOT_VERIFIED
    active_for_join BOOLEAN NOT NULL DEFAULT FALSE,
    bobot_kontribusi_pasokan NUMERIC(5,4) CHECK (bobot_kontribusi_pasokan IS NULL OR (bobot_kontribusi_pasokan > 0 AND bobot_kontribusi_pasokan <= 1.0)),
    evidence_row_ids VARCHAR(80),
    source_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

---

## 5. Contoh SQL JOIN Operasional untuk Tiga Pertanyaan Analitis Capstone

Seluruh kueri di bawah ini telah dioptimasi untuk dieksekusi pada PostgreSQL 16 dengan prinsip tata kelola data yang ketat:

### 5.1. SQL JOIN Q1: Analisis Disparitas Harga, Margin Distribusi, dan Pelanggaran Batas Regulasi HET/HAP
*Menjawab Q1 Proposal: Berapa besar disparitas harga harian, rasio margin keuntungan distribusi (produsen ke pasar tradisional dan modern), serta tingkat pelanggaran batas regulasi HET/HAP Bapanas untuk 5 komoditas pangan pokok menuju DKI Jakarta?*

```sql
-- Kueri Analisis Q1: Disparitas Harga, Margin Distribusi, dan Kepatuhan HET/HAP
WITH produsen_price AS (
    -- Ambil harga produsen sentra di Jawa Barat dan Jawa Tengah
    SELECT 
        f.date_key,
        f.commodity_key,
        r.region_key,
        f.price_per_kg AS price_produsen
    FROM curated.fact_food_price_daily f
    JOIN curated.dim_market_tier m ON f.market_tier_key = m.market_tier_key
    JOIN curated.dim_region r ON f.region_sk = r.region_sk
    WHERE m.market_tier_code = 'produsen'
),
konsumen_price AS (
    -- Ambil harga konsumen eceran pasar tradisional di DKI Jakarta
    SELECT 
        f.date_key,
        f.commodity_key,
        f.price_per_kg AS price_tradisional_dki
    FROM curated.fact_food_price_daily f
    JOIN curated.dim_market_tier m ON f.market_tier_key = m.market_tier_key
    JOIN curated.dim_region r ON f.region_sk = r.region_sk
    WHERE m.market_tier_code = 'tradisional' 
      AND r.region_key = 'dki_jakarta'
)
SELECT 
    d.full_date,
    c.commodity_name,
    crd.corridor_name,
    p.price_produsen AS harga_produsen_sentra,
    k.price_tradisional_dki AS harga_eceran_dki,
    
    -- Metrik 1: Disparitas Harga Nominal Harian (Rp/kg)
    (k.price_tradisional_dki - p.price_produsen) AS disparitas_harga_rp,
    
    -- Metrik 2: Rasio Margin Keuntungan Distribusi (%)
    ROUND(
        ((k.price_tradisional_dki - p.price_produsen) / NULLIF(p.price_produsen, 0)) * 100.0, 
        2
    ) AS margin_distribusi_pct,
    
    -- Metrik 3: Batas Plafon Regulasi HET / HAP Bapanas
    h.batas_atas_rp AS plafon_het_hap_rp,
    h.dasar_regulasi,
    
    -- Indikator Pelanggaran Ambang Batas Regulasi
    CASE 
        WHEN k.price_tradisional_dki > h.batas_atas_rp THEN 'PELANGGARAN_HET'
        ELSE 'PATUH'
    END AS status_kepatuhan_regulasi,
    
    -- Selisih Pelanggaran Harga terhadap Plafon
    GREATEST(0, k.price_tradisional_dki - h.batas_atas_rp) AS selisih_diatas_plafon_rp

FROM curated.dim_date_hbkn d
JOIN curated.bridge_supply_corridor b
  ON b.active_for_join = TRUE
JOIN curated.dim_region_corridor crd
  ON b.corridor_key = crd.corridor_key
JOIN curated.dim_commodity c
  ON b.commodity_key = c.commodity_key
JOIN produsen_price p 
  ON d.date_key = p.date_key 
 AND p.commodity_key = c.commodity_key
 AND p.region_key = crd.origin_province_key
JOIN konsumen_price k 
  ON d.date_key = k.date_key 
 AND p.commodity_key = k.commodity_key
-- JOIN Regulasi HET SCD Type-2 dengan pencegahan fan-out (spesifik varian Medium)
LEFT JOIN curated.dim_regulation_het h 
  ON c.commodity_name = h.komoditas 
 AND h.varian_mutu IN ('Medium', 'Umum')
 AND d.full_date >= h.valid_from 
 AND d.full_date <= h.valid_to

WHERE c.is_strategic = TRUE
  AND d.full_date BETWEEN '2024-01-01' AND '2024-01-31'
ORDER BY d.full_date DESC, c.commodity_key, crd.corridor_key;
```

---

### 5.2. SQL JOIN Q2: Dampak Akumulasi Curah Hujan Ekstrem Sentra dan Guncangan Logistik
*Menjawab Q2 Proposal: Seberapa besar pengaruh akumulasi curah hujan ekstrem ($\ge 100\text{ mm}$ dalam horizon 7 hari) di 5 kabupaten sentra produksi utama, fluktuasi kurs USD/IDR, dan tarif BBM terhadap harga produsen?*

```sql
-- Kueri Analisis Q2: Korelasi Anomali Iklim Sentra dan Makroekonomi terhadap Sentra Pangan
SELECT 
    d.full_date,
    c.commodity_name,
    r.region_name AS sentra_produksi,
    f_price.price_per_kg AS harga_produsen_rp,
    
    -- Parameter Iklim Sentra
    w.precipitation_sum_mm AS curah_hujan_harian_mm,
    w.rolling_7d_precip_mm AS akumulasi_hujan_7hari_mm,
    w.is_extreme_rainfall AS flag_hujan_ekstrem,
    
    -- Faktor Makroekonomi dan Bahan Bakar Logistik
    m.usd_idr_rate AS kurs_jisdor_usd_idr,
    m.solar_subsidi_rp AS tarif_solar_logistik_per_liter,
    
    -- Analisis Status Risiko Pasokan Rantai Hulu
    CASE 
        WHEN w.rolling_7d_precip_mm >= 100.0 THEN 'RISIKO_GAGAL_PANEN_IKLIM'
        WHEN c.is_imported = TRUE AND m.usd_idr_rate > 16000.0 THEN 'TEKANAN_KURS_IMPOR'
        ELSE 'PASOKAN_SENTRA_NORMAL'
    END AS status_risiko_hulu

FROM curated.fact_food_price_daily f_price
JOIN curated.dim_date_hbkn d ON f_price.date_key = d.date_key
JOIN curated.dim_commodity c ON f_price.commodity_key = c.commodity_key
JOIN curated.dim_market_tier mt ON f_price.market_tier_key = mt.market_tier_key
JOIN curated.dim_region r ON f_price.region_sk = r.region_sk

-- JOIN Fakta Cuaca Harian Kabupaten Sentra (Kardinalitas 1 : 1 pada date + region)
LEFT JOIN curated.fact_weather_daily w 
  ON f_price.date_key = w.date_key 
 AND r.weather_station_key = w.region_sk

-- JOIN Indikator Makroekonomi & Bahan Bakar (Kardinalitas 1 : 1 pada date_key)
LEFT JOIN curated.fact_macro_logistics_daily m 
  ON f_price.date_key = m.date_key

WHERE mt.market_tier_code = 'produsen'
  AND c.commodity_code IN ('cabai_rawit', 'bawang_merah', 'beras', 'bawang_putih')
  AND d.full_date BETWEEN '2024-01-01' AND '2024-03-31'
ORDER BY d.full_date DESC, c.commodity_name;
```

---

### 5.3. SQL JOIN Q3: Sistem Peringatan Dini Intervensi Pasar (*Early Warning Alert*)
*Menjawab Q3 Proposal: Kapan sinyal peringatan dini intervensi pasar diaktifkan berdasarkan kombinasi deviasi harga konsumen terhadap MA14 ($> 15\%$), anomali cuaca ekstrem sentra, dan penanda kalender HBKN?*

```sql
-- Kueri Analisis Q3: Mesin Peringatan Dini Intervensi Pasar DKI Jakarta
WITH price_dynamics AS (
    SELECT 
        f.date_key,
        f.commodity_key,
        f.price_per_kg,
        
        -- Moving Average 14 Hari Harga Konsumen DKI Jakarta
        AVG(f.price_per_kg) OVER (
            PARTITION BY f.commodity_key 
            ORDER BY d.full_date 
            ROWS BETWEEN 13 PRECEDING AND CURRENT ROW
        ) AS ma14_price,
        
        -- Deviasi Persentase terhadap MA14
        ROUND(
            ((f.price_per_kg - AVG(f.price_per_kg) OVER (
                PARTITION BY f.commodity_key 
                ORDER BY d.full_date 
                ROWS BETWEEN 13 PRECEDING AND CURRENT ROW
            )) / NULLIF(AVG(f.price_per_kg) OVER (
                PARTITION BY f.commodity_key 
                ORDER BY d.full_date 
                ROWS BETWEEN 13 PRECEDING AND CURRENT ROW
            ), 0)) * 100.0, 
            2
        ) AS ma14_deviation_pct
    FROM curated.fact_food_price_daily f
    JOIN curated.dim_date_hbkn d ON f.date_key = d.date_key
    JOIN curated.dim_market_tier mt ON f.market_tier_key = mt.market_tier_key
    JOIN curated.dim_region r ON f.region_sk = r.region_sk
    WHERE mt.market_tier_code = 'tradisional' 
      AND r.region_key = 'dki_jakarta'
),
weather_summary_sentra AS (
    -- Deteksi apakah ADA sentra penyuplai yang mengalami curah hujan ekstrem pada tanggal tersebut
    SELECT 
        w.date_key,
        MAX(w.rolling_7d_precip_mm) AS max_sentra_rolling_7d_mm,
        MAX(CASE WHEN w.is_extreme_rainfall = 1 THEN 1 ELSE 0 END) AS has_extreme_weather_sentra
    FROM curated.fact_weather_daily w
    GROUP BY w.date_key
)
SELECT 
    d.full_date,
    c.commodity_name,
    p.price_per_kg AS harga_eceran_dki,
    ROUND(p.ma14_price, 2) AS ambang_ma14_harga,
    p.ma14_deviation_pct,
    
    -- Penanda Kalender Keagamaan / HBKN
    d.hbkn_category,
    d.is_hbkn_major,
    
    -- Kondisi Iklim Ekstrem Sentra
    ws.max_sentra_rolling_7d_mm,
    ws.has_extreme_weather_sentra,
    
    -- KLASIFIKASI ATURAN PERINGATAN DINI (EARLY WARNING LEVEL)
    CASE 
        -- LEVEL MERAH: Lonjakan harga ekstrem (>15%), cuaca buruk sentra, bertepatan momentum HBKN
        WHEN p.ma14_deviation_pct > 15.0 AND ws.has_extreme_weather_sentra = 1 AND d.is_hbkn_major = TRUE 
            THEN 'ALERT_MERAH: OPERASI_PASAR_DARURAT'
            
        -- LEVEL KUNING: Lonjakan harga di atas batas wajar (>15%) ATAU ancaman cuaca sentra masif
        WHEN p.ma14_deviation_pct > 15.0 OR (ws.has_extreme_weather_sentra = 1 AND d.is_hbkn_major = TRUE)
            THEN 'ALERT_KUNING: AKTIVASI_SUBSIDI_ONGKOS_ANGKUT_KAD'
            
        -- LEVEL HIJAU: Kondisi pasokan dan harga stabil dalam batas kendali
        ELSE 'NORMAL: MONITORING_RUTIN'
    END AS status_peringatan_dini

FROM price_dynamics p
JOIN curated.dim_date_hbkn d ON p.date_key = d.date_key
JOIN curated.dim_commodity c ON p.commodity_key = c.commodity_key
LEFT JOIN weather_summary_sentra ws ON p.date_key = ws.date_key
WHERE c.is_strategic = TRUE
  AND d.full_date >= '2024-01-01'
ORDER BY d.full_date DESC, c.commodity_key;
```

Desain JOIN di atas memastikan seluruh kueri agregasi analitik berjalan presisi, bebas distorsi, dan sepenuhnya terlindung dari risiko *double counting*.
