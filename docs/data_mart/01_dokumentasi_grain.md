# DOKUMENTASI GRAIN: DATA MART PEMANTAUAN VOLATILITAS PANGAN DAN ANOMALI IKLIM KORIDOR JAWA BARAT – DKI JAKARTA
**Proyek Capstone Data Engineering — Group A03**  
**Versi:** 1.1 (Updated & Verified with SRC-01..SRC-13 Complete Snapshot)  
**Status Dokumen:** Terverifikasi Penuh terhadap `SNAPSHOT_MANIFEST.md` dan Seluruh Dataset Aktual (`SRC-01..SRC-13`)

---

## 1. Pendahuluan dan Latar Belakang Desain

Perancangan Data Mart ini bertujuan untuk mendukung pengambilan keputusan **Tim Pengendalian Inflasi Daerah (TPID)** dan **Dinas Ketahanan Pangan, Kelautan, dan Pertanian (KPKP) Provinsi DKI Jakarta** dalam:
1. Memantau disparitas harga nominal harian dan margin distribusi hulu-ke-hilir (produsen $\rightarrow$ pasar tradisional & modern).
2. Mendeteksi anomali cuaca ekstrem (akumulasi curah hujan bergerak $\ge 100\text{ mm}$ dalam horizon 7 hari) di 5 kabupaten sentra penyuplai utama (Kab. Garut, Kab. Magelang, Kab. Karawang, Kab. Indramayu, dan Kab. Brebes).
3. Menganalisis dampak guncangan makroekonomi (fluktuasi kurs USD/IDR untuk pangan impor seperti bawang putih) dan tarif logistik (BBM subsidi Solar & Pertalite).
4. Mengeluarkan sinyal peringatan dini intervensi pasar (*Early Market Intervention Alert*) saat harga melampaui ambang batas deviasi *Moving Average* 14 hari ($> 15\%$) atau menembus batas Harga Eceran Tertinggi (HET) / Harga Acuan Penjualan (HAP) Badan Pangan Nasional (Bapanas).

Sesuai metodologi *dimensional modeling* Ralph Kimball, penetapan *grain* (butir granularitas terendah) adalah fondasi paling krusial sebelum menentukan tabel dimensi dan fakta. Ketidaktepatan penetapan grain akan memicu inkonsistensi matematis, *Cartesian product*, perangkap duplikasi (*fan-out*), dan penggandaan nilai (*double counting*).

---

## 2. Identifikasi Tabel Fakta (*Fact Tables*)

Berdasarkan analisis struktur 13 sumber data logis (22 tabel/file sumber fisik) yang tersedia pada direktori `workspace/data/`, arsitektur Data Mart dirancang menggunakan pendekatan **Fact Constellation (Galaxy Schema)** yang terdiri dari **3 Tabel Fakta Atomik (*Atomic Fact Tables*)** dan **1 Tabel Fakta Terintegrasi (*Consolidated Analytical Fact Table*)**:

| Schema | Nama Tabel Fakta | Tipe Fakta | Peran Utama | Sumber Data Fisik Aktual |
| :--- | :--- | :--- | :--- | :--- |
| `curated` | `fact_food_price_daily` | *Transaction / Periodic Snapshot* | Mencatat observasi harga pangan murni per wilayah tanpa distorsi koridor | PIHPS Bank Indonesia (`final_komoditas_tradisional_*.csv`, `final_komoditas_modern_*.csv`, `final_komoditas_produsen_*.csv`) |
| `curated` | `fact_weather_daily` | *Periodic Snapshot* | Mencatat metrik cuaca harian dan kalkulasi horizon akumulasi hujan | Open-Meteo ERA5 (`cuaca garut.csv`, dll.), `openmeteo_live_latest.csv`, agregat harian `bmkg_station_ref.csv` |
| `curated` | `fact_macro_logistics_daily` | *Periodic Snapshot* | Mencatat indikator kurs transaksi USD/IDR dan harga BBM logistik | Bank Indonesia / Frankfurter (`bi_jisdor_daily.csv`), Kementerian ESDM (`ref_bbm_esdm.csv`) |
| `curated` | `fact_food_supply_daily` | *Consolidated / Accumulating Snapshot* | Tabel fakta inti analitik yang menggabungkan transmisi harga sentra $\rightarrow$ DKI, disparitas, margin, dan risiko cuaca | Konsolidasi seluruh fakta atomik, `ref_bapanas_het.csv`, dan `ref_supply_corridor.csv` (`SRC-12`) |

---

## 3. Spesifikasi Grain Setiap Fact Table

### 3.1. `curated.fact_food_price_daily` (Fakta Harga Pangan Harian)
- **Pernyataan Grain:**  
  *Satu baris merepresentasikan catatan harga rata-rata satu komoditas pangan pokok pada satu tingkat pasar (produsen, pasar tradisional, pasar modern) di satu wilayah administratif (provinsi) pada satu tanggal kalender.*
- **Kombinasi Kunci Grain (*Grain Keys*):**  
  `date_key` + `commodity_key` + `market_tier_key` + `region_key`
- **Satu Baris Merepresentasikan:**  
  Harga transaksi komoditas $C$ pada tingkat pasar $T$ di provinsi $R$ pada tanggal $D$.  
  *Contoh aktual:* Pada tanggal 1 Januari 2022 (`date_key = 20220101`), komoditas Beras (`commodity_key = 1`), tingkat pasar tradisional (`market_tier_key = 'tradisional'`), di provinsi DKI Jakarta (`region_key = 'dki_jakarta'`), harga tercatat adalah Rp 13.550,00 per kg.
- **Karakteristik Metrik:**
  - `price_per_kg`: *Additive across distinct commodities/regions if weighted, non-additive across time* (menggunakan `AVG` untuk agregasi waktu, bukan `SUM`).
  - `prev_day_price`: *Non-additive* (harga lag 1 hari).
  - `daily_price_change_rp`: *Additive across price delta*, dihitung dari $P_t - P_{t-1}$.
  - `daily_price_change_pct`: *Non-additive* (persentase).
  - `ma14_price`: *Non-additive* (rata-rata bergerak 14 hari).
  - `ma14_deviation_pct`: *Non-additive* (deviasi persentase terhadap MA14).

---

### 3.2. `curated.fact_weather_daily` (Fakta Cuaca dan Iklim Sentra Harian)
- **Pernyataan Grain:**  
  *Satu baris merepresentasikan ringkasan pengukuran parameter iklim harian (suhu maksimum, total curah hujan) pada satu stasiun/koordinat kabupaten sentra atau pasar konsumen pada satu tanggal kalender.*
- **Kombinasi Kunci Grain (*Grain Keys*):**  
  `date_key` + `region_key`
- **Satu Baris Merepresentasikan:**  
  Kondisi iklim fisik pada wilayah/kabupaten $R$ pada tanggal $D$.  
  *Contoh aktual:* Pada tanggal 1 Januari 2022 (`date_key = 20220101`), di Kabupaten Garut (`region_key = 'garut'`), suhu maksimum tercatat 27,0 °C, curah hujan harian 3,70 mm, dan akumulasi hujan 7 hari bergerak (*rolling 7-day*) sebesar 24,50 mm.
- **Karakteristik Metrik:**
  - `temperature_max_c`: *Non-additive across time and space* (menggunakan `AVG`, `MAX`, atau `MIN`).
  - `precipitation_sum_mm`: *Additive across time* (dapat dijumlahkan untuk horizon mingguan/bulanan), *non-additive across distinct stations*.
  - `rain_sum_mm`: *Additive across time*.
  - `rolling_7d_precip_mm`: *Semi-additive* (metrik windowing bergerak).
  - `is_extreme_rainfall`: *Non-additive flag* (1 jika `rolling_7d_precip_mm` $\ge 100\text{ mm}$, 0 jika normal).

---

### 3.3. `curated.fact_macro_logistics_daily` (Fakta Makroekonomi & Logistik Harian)
- **Pernyataan Grain:**  
  *Satu baris merepresentasikan nilai tukar acuan kurs USD/IDR serta tarif regulasi bahan bakar minyak (BBM) logistik per jenis bahan bakar yang berlaku pada satu tanggal kalender.*
- **Kombinasi Kunci Grain (*Grain Keys*):**  
  `date_key` + `fuel_key` (atau pivot `(date_key)` dengan kolom eksplisit solar dan pertalite).
- **Satu Baris Merepresentasikan:**  
  Kondisi moneter kurs dan tarif energi logistik armada distribusi pangan pada tanggal $D$.  
  *Contoh aktual:* Pada tanggal 1 September 2022 (`date_key = 20220901`), kurs Jisdor tercatat Rp 14.853,00 per USD, harga Biosolar subsidi Rp 5.150,00 per liter, dan Pertalite Rp 7.650,00 per liter. Pada 3 September 2022, harga Biosolar melonjak menjadi Rp 6.800,00 per liter dan Pertalite Rp 10.000,00 per liter.
- **Karakteristik Metrik:**
  - `usd_idr_rate`: *Non-additive* (kurs harian).
  - `bbm_price_per_liter`: *Non-additive* (tarif regulasi).
  - `fx_daily_change_pct`: *Non-additive*.

---

### 3.4. `curated.fact_food_supply_daily` (Fakta Analitik Terintegrasi Koridor Pasokan)
- **Pernyataan Grain:**  
  *Satu baris merepresentasikan keterpaduan metrik transmisi harga produsen ke konsumen DKI Jakarta, disparitas harga nominal, margin keuntungan distribusi, anomali iklim di kabupaten sentra pemasok, kepatuhan batas regulasi HET/HAP, dan indikator peringatan dini untuk satu komoditas strategis pada satu koridor pasokan spesifik per tanggal kalender.*
- **Kombinasi Kunci Grain (*Grain Keys*):**  
  `date_key` + `commodity_key` + `corridor_key`
- **Satu Baris Merepresentasikan:**  
  Kinerja rantai pasok dan risiko transmisi pangan untuk komoditas $C$ yang mengalir dari sentra asal $Origin$ menuju pasar tujuan DKI Jakarta melalui koridor $K$ pada tanggal $D$.  
  *Contoh aktual:* Pada tanggal 3 Januari 2022 (`date_key = 20220103`), untuk komoditas Beras (`commodity_key = 1`) pada koridor Karawang $\rightarrow$ DKI Jakarta (`corridor_key = 3`):
  - Harga Produsen Sentra (Jawa Barat): Rp 8.950,00/kg
  - Harga Konsumen DKI Jakarta (Pasar Tradisional): Rp 13.550,00/kg
  - Disparitas Harga: Rp 4.600,00/kg
  - Rasio Margin Distribusi: 51,40%
  - Batas Atas HET Beras Medium Zona 1: Rp 9.450,00/kg
  - Deviasi terhadap Batas HET: +Rp 4.100,00/kg (Pelanggaran ambang batas HET)
  - Curah Hujan 7 Hari Sentra Karawang: 18,20 mm (Normal, $<100\text{ mm}$)
  - Status Early Warning Alert: Waspada HET (Harga eceran di atas plafon regulasi).

---

## 4. Analisis Potensi Duplikasi dan Perbedaan Granularitas

Integrasi multi-sumber ini melibatkan heterogenitas data yang sangat tinggi. Berikut identifikasi ketidaksesuaian granularitas (*granularity mismatch*) dan solusi perancangan sistemnya:

```
+---------------------------------------------------------------------------------------------------+
| DIMENSI              GRANULARITAS SUMBER                          GRANULARITAS TARGET DATA MART   |
+---------------------------------------------------------------------------------------------------+
| Temporal (Waktu)     - PIHPS: Harian (Senin-Minggu, 1.415-1.493)  - Target: Harian (Daily)        |
|                      - Open-Meteo: Harian (1.504 hari)            - date_key: YYYYMMDD            |
|                      - JISDOR FX: Hari Kerja Bank (1.250 hari)    - Imputasi forward-fill untuk   |
|                      - BMKG: 3-Jam-an (3-hourly slots)              hari libur / non-banking days |
|                      - ESDM / HET: Rentang Tanggal (SCD Type-2)   - Agregasi MAX/AVG untuk BMKG   |
+---------------------------------------------------------------------------------------------------+
| Spasial (Wilayah)    - PIHPS: Provinsi (DKI, Jabar, Jateng)       - Conformed dim_region          |
|                      - Open-Meteo: Koordinat Stasiun (Kabupaten)  - Jembatan Koridor Sentra       |
|                      - BMKG: Tingkat Desa/Kelurahan (adm4)        - Rollup adm4 ke Kabupaten      |
|                      - JISDOR / BBM: Tingkat Nasional             - Pemisahan entitas pasar vs    |
|                      - BPS / Neraca: Koridor Pemasok (Antardaerah)  sentra melalui bridge table   |
+---------------------------------------------------------------------------------------------------+
| Komoditas & Varian   - PIHPS: Komoditas Agregat ("Beras")         - Standar 5 Komoditas Strategis |
|                      - Bapanas HET: Tingkat Mutu/Varian           - Default baseline mutu medium  |
|                        ("Beras Medium", "Beras Premium")            untuk evaluasi HET konsumen   |
|                      - Open Data DKI: 46 Nama Varian Ritel Detail - Standarisasi ke canonical key |
+---------------------------------------------------------------------------------------------------+
```

### 4.1. Perbedaan Granularitas Temporal
1. **Hari Libur dan Akhir Pekan pada Kurs USD/IDR (`bi_jisdor_daily.csv`):**
   - *Isu:* Dataset JISDOR hanya memiliki 1.250 baris karena pasar valuta asing tutup pada akhir pekan dan hari libur nasional. Sebaliknya, pasar pangan dan cuaca beroperasi 7 hari seminggu (1.504 hari).
   - *Risiko:* Jika dilakukan `INNER JOIN` biasa, data harga pangan pada hari Sabtu dan Minggu akan tereliminasi (*data loss* 17% data historis).
   - *Mitigasi:* Menggunakan teknik **Forward-Fill (Last Observation Carried Forward / LOCF)** pada lapisan staging (`stg`), di mana nilai kurs hari Jumat dibawa ke hari Sabtu dan Minggu, atau menggunakan `LEFT JOIN` dari `dim_date`.

2. **Granularitas Sub-Harian BMKG (`bmkg_station_ref.csv`):**
   - *Isu:* API BMKG merilis prakiraan cuaca per slot 3 jam (`07:00`, `10:00`, `13:00`, dst.) dengan total 120 baris per panggilan API.
   - *Risiko:* Menggabungkan data BMKG 3 jam-an langsung ke tabel fakta harian akan menyebabkan penggandaan baris (*fan-out* 8x per hari per wilayah).
   - *Mitigasi:* Melakukan agregasi harian di lapisan staging: $T_{\text{max}} = \max(T)$, $HU_{\text{avg}} = \text{avg}(HU)$, $TP_{\text{sum}} = \sum(TP)$ sebelum dimuat ke `curated.fact_weather_daily`.

3. **Granularitas Rentang Waktu SCD Type-2 (`ref_bapanas_het.csv` dan `ref_bbm_esdm.csv`):**
   - *Isu:* Data regulasi HET dan tarif BBM tidak disimpan per hari, melainkan per periode berlakunya regulasi (`valid_from` s.d. `valid_to`).
   - *Mitigasi:* Menghubungkan tabel fakta harian menggunakan klausa evaluasi temporal:  
     `ON fact.full_date >= reg.valid_from AND fact.full_date <= reg.valid_to`.

---

### 4.2. Perbedaan Granularitas Spasial dan Masalah Penggandaan Nilai (*Double Counting*)

> [!WARNING]
> **PERHATIAN KRUSIAL: PENGGANDAAN HARGA DKI JAKARTA PADA KORIDOR SENTRA**  
> DKI Jakarta adalah **satu pasar konsumen tunggal**, namun menerima pasokan dari **banyak kabupaten sentra**. Sebagai contoh, komoditas Beras dipasok bersamaan oleh Kab. Karawang dan Kab. Indramayu. Jika harga pasar DKI Jakarta dituliskan langsung sebagai kolom fakta di setiap baris koridor, maka harga DKI Jakarta akan muncul berulang kali pada tanggal yang sama!

#### Simulasi Penggandaan Nilai (Tanpa Pengendalian Grain):
Misalkan pada tanggal `2022-01-03`, harga pasar tradisional DKI Jakarta untuk Beras adalah **Rp 13.550/kg**.
Jika dimuat secara naif ke tabel koridor:
- Baris 1: `(2022-01-03, Beras, Karawang -> DKI, Harga_Produsen=8950, Harga_Konsumen_DKI=13550)`
- Baris 2: `(2022-01-03, Beras, Indramayu -> DKI, Harga_Produsen=8950, Harga_Konsumen_DKI=13550)`

Jika analis menjalankan kueri agregasi:
```sql
SELECT date_key, commodity_key, SUM(consumer_price_dki)
FROM fact_food_supply_daily
WHERE date_key = 20220103 AND commodity_key = 1
GROUP BY date_key, commodity_key;
```
Hasil `SUM` akan menghasilkan **Rp 27.100**, yang merupakan **kesalahan fatal (double counting 200%)**.

#### Solusi Arsitektural Data Mart:
1. **Pemisahan Fakta Atomik (`fact_food_price_daily`):**  
   Pencatatan harga murni DKI Jakarta disimpan pada `fact_food_price_daily` dengan grain `(date_key, commodity_key, market_tier_key, region_key)`. Di tabel ini, DKI Jakarta **hanya memiliki tepat 1 baris per komoditas per tingkat pasar per hari**, sehingga operasi `AVG()` maupun `SUM()` antar-komoditas terjamin valid tanpa distorsi.
2. **Karakterisasi Metrik pada Fakta Koridor (`fact_food_supply_daily`):**  
   Kolom `consumer_price_dki` di tabel koridor dideklarasikan sebagai **Semi-Additive / Non-Additive across corridors**.
3. **Penerapan Bridge Table & Status Verifikasi `SRC-12` (`ref_supply_corridor.csv`):**  
   Berdasarkan file aktual `workspace/data/ref_supply_corridor.csv` (9 baris: `COR-01..COR-09`):
   - Hanya 4 koridor (`COR-01..COR-04`: Cabai Rawit Merah & Cabai Merah Keriting dari Kab. Garut & Kab. Magelang) berstatus `OBSERVED_FDP` dan `active_for_join = TRUE`.
   - `COR-05..COR-08` (Beras & Bawang Merah) berstatus `PROPOSED_UNVERIFIED` (`active_for_join = FALSE`).
   - `COR-09` (Bawang Putih) berstatus `NOT_VERIFIED` (`origin_unresolved`, `active_for_join = FALSE`; selain itu CSV produsen `bawang_putih` di `SRC-03` hanya memuat Kalut & NTB, bukan Jabar/Jateng).
   - Kolom `bobot_kontribusi_pasokan` saat ini bernilai `NULL` pada seluruh 9 baris (*FDP 2024 sample, NOT market-wide supply share*). Oleh karena itu, kueri analitik **dilarang** melakukan pembobotan fiktif dan hanya boleh men-join koridor yang berstatus `active_for_join = TRUE`, serta tidak boleh menjumlahkan (`SUM`) harga DKI lintas koridor.

---

### 4.3. Potensi Duplikasi pada Kalender Libur HBKN (`ref_hbkn_calendar.csv`)
- **Temuan Validasi Data Aktual:**  
  Hasil verifikasi script terhadap `ref_hbkn_calendar.csv` menemukan bahwa terdapat tanggal yang memiliki **lebih dari satu hari libur**:
  - `2023-03-23`: `1 Ramadan` (Kategori: `RAMADAN`, `is_hbkn_major = True`) DAN `Cuti Bersama Hari Suci Nyepi` (Kategori: `PUBLIC_HOLIDAY`, `is_hbkn_major = False`).
  - `2024-03-12`: `1 Ramadan` (Kategori: `RAMADAN`, `is_hbkn_major = True`) DAN `Cuti Bersama Hari Suci Nyepi` (Kategori: `PUBLIC_HOLIDAY`, `is_hbkn_major = False`).
- **Risiko Fan-Out:**  
  Jika `fact_food_price_daily` di-join langsung ke `ref_hbkn_calendar` secara `1 : M` pada kolom tanggal, baris fakta pada kedua tanggal tersebut akan berlipat ganda menjadi 2 baris per entitas komoditas!
- **Mitigasi:**  
  Tabel dimensi tanggal `dim_date_hbkn` dirancang strictly **1 baris per hari kalender (grain murni harian)**. Atribut hari libur di-rollup pada proses ETL/ELT dengan aturan hierarki prioritas: jika suatu tanggal memiliki hari libur nasional dan HBKN keagamaan mayor, maka `hbkn_category` mengutamakan kategori HBKN mayor (`RAMADAN`), sedangkan nama hari libur dikonsolidasikan (`'1 Ramadan; Cuti Bersama Nyepi'`).

---

### 4.4. Ketidaksesuaian Granularitas Varian Komoditas Beras pada HET
- **Temuan Validasi Data Aktual:**  
  - Pada `ref_bapanas_het.csv`, komoditas `Beras` dipecah menjadi dua varian mutu: `Medium` (HET Rp 9.450 $\rightarrow$ Rp 10.900 $\rightarrow$ Rp 12.500 $\rightarrow$ Rp 13.500) dan `Premium` (HET Rp 12.800 $\rightarrow$ Rp 13.900 $\rightarrow$ Rp 14.900).
  - Pada dataset harga pasar PIHPS (`final_komoditas_tradisional_beras_2022_2026.csv`), harga dilaporkan dalam satu label umum (`beras`).
- **Risiko Fan-Out:**  
  Jika penggabungan hanya menggunakan `komoditas = 'beras'` dan rentang tanggal, setiap baris beras akan berlipat ganda menjadi 2 baris (satu untuk Medium, satu untuk Premium).
- **Mitigasi:**  
  Dalam arsitektur analitik TPID DKI Jakarta, harga beras eceran PIHPS dibandingkan dengan **HET Beras Medium Zona 1** sebagai acuan stabilisasi pangan pokok masyarakat, dengan menetapkan predikat filter `varian_mutu = 'Medium'` pada join HET default, atau menyediakan kolom terpisah `het_beras_medium_rp` dan `het_beras_premium_rp` pada tabel fakta analitik.

---

## 5. Ringkasan Matriks Granularitas Antar-Tabel

```
+------------------------------+------------------------------------------+-----------------------+---------------------+
| Tabel                        | Grain Konseptual                         | Primary / Grain Key   | Estimasi Baris      |
+------------------------------+------------------------------------------+-----------------------+---------------------+
| dim_date_hbkn                | 1 baris per hari kalender                | date_key (YYYYMMDD)   | 1.504 baris         |
| dim_commodity                | 1 baris per komoditas strategis          | commodity_key (INT)   | 5 - 10 baris        |
| dim_region                   | 1 baris per wilayah / stasiun / pasar    | region_key (VARCHAR)  | 6 - 8 baris         |
| dim_region_corridor          | 1 baris per koridor sentra -> DKI        | corridor_key (INT)    | 5 - 8 pasangan rute |
| dim_regulation_het           | 1 baris per periode versi regulasi HET   | het_key (INT)         | 12 baris (SCD-2)    |
| dim_macro_logistics          | 1 baris per periode versi tarif BBM      | fuel_key (INT)        | 4 baris (SCD-2)     |
| bridge_supply_corridor       | 1 baris per entri ref_supply_corridor    | bridge_id (INT)       | 9 baris (4 aktif)   |
+------------------------------+------------------------------------------+-----------------------+---------------------+
| fact_food_price_daily        | 1 baris per komoditas-tier-wilayah-hari  | date+com+tier+reg     | ~45.000 baris       |
| fact_weather_daily           | 1 baris per stasiun sentra/pasar-hari    | date+reg              | 9.024 baris (arsip) |
| fact_macro_logistics_daily   | 1 baris per hari kalender                | date_key              | 1.504 baris         |
| fact_food_supply_daily       | 1 baris per komoditas-koridor-hari       | date+com+crd          | ~6.016 (4 aktif)    |
+------------------------------+------------------------------------------+-----------------------+---------------------+
```

Dokumentasi grain ini menjadi acuan mutlak bagi penentuan Business Key, relasi JOIN, dan pembuatan draft ERD pada bagian selanjutnya.
