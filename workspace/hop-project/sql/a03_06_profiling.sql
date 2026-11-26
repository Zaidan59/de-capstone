-- P1: hari kosong per seri harian PIHPS
WITH s AS (SELECT market_tier, commodity, MIN(date_param::date) d0, MAX(date_param::date) d1, COUNT(DISTINCT date_param) n
           FROM raw.pihps_market_prices GROUP BY 1,2)
SELECT 'P1' AS profil, market_tier, commodity, (d1-d0+1) AS hari_kalender, n AS hari_ada, (d1-d0+1)-n AS hari_kosong,
       ROUND(100.0*n/(d1-d0+1),1) AS pct_terisi
FROM s ORDER BY 2,3;
-- P2: nilai harga tidak bulat (artefak imputasi)
SELECT 'P2' AS profil, COUNT(*) AS total_nilai,
       COUNT(*) FILTER (WHERE ABS(v-ROUND(v)) > 0.000001) AS nilai_tak_bulat,
       ROUND(100.0*COUNT(*) FILTER (WHERE ABS(v-ROUND(v)) > 0.000001)/COUNT(*),2) AS pct_tak_bulat
FROM (SELECT unnest(ARRAY[dki_jakarta,jawa_barat,jawa_tengah])::numeric AS v FROM raw.pihps_market_prices) t
WHERE v IS NOT NULL;
-- P3: nama komoditas DKI yang berganti nama
SELECT 'P3' AS profil, komoditas, MIN(periode_data) AS dari, MAX(periode_data) AS sampai, COUNT(*) AS n
FROM raw.dki_harga_pokok_bulanan WHERE komoditas LIKE 'BERAS MUNCUL%' GROUP BY 2 ORDER BY 3;
-- P4 (versi aman): harga DKI kosong, non-numerik, atau nol per komoditas
WITH d AS (
  SELECT komoditas,
         (harga_raw IS NULL OR TRIM(harga_raw) = '') AS kosong,
         (TRIM(COALESCE(harga_raw,'')) <> '' AND TRIM(harga_raw) !~ '^-?[0-9]+(\.[0-9]+)?$') AS non_numerik,
         (CASE WHEN TRIM(COALESCE(harga_raw,'')) ~ '^-?[0-9]+(\.[0-9]+)?$' THEN TRIM(harga_raw)::numeric END <= 0) AS nol
  FROM raw.dki_harga_pokok_bulanan)
SELECT 'P4' AS profil, komoditas,
       COUNT(*) FILTER (WHERE kosong) AS kosong,
       COUNT(*) FILTER (WHERE non_numerik) AS non_numerik,
       COUNT(*) FILTER (WHERE nol) AS nol
FROM d GROUP BY 2
HAVING COUNT(*) FILTER (WHERE kosong OR non_numerik OR nol) > 0
ORDER BY 3 DESC, 4 DESC LIMIT 5;
-- P4b: total keseluruhan harga DKI bermasalah
SELECT 'P4b' AS profil, COUNT(*) AS total_baris,
       COUNT(*) FILTER (WHERE harga_raw IS NULL OR TRIM(harga_raw) = '') AS kosong,
       COUNT(*) FILTER (WHERE TRIM(COALESCE(harga_raw,'')) <> '' AND TRIM(harga_raw) !~ '^-?[0-9]+(\.[0-9]+)?$') AS non_numerik,
       COUNT(*) FILTER (WHERE CASE WHEN TRIM(COALESCE(harga_raw,'')) ~ '^-?[0-9]+(\.[0-9]+)?$' THEN TRIM(harga_raw)::numeric END <= 0) AS nol_atau_negatif
FROM raw.dki_harga_pokok_bulanan;
-- P5: konsistensi SCD2 tabel BBM dan HET/HAP
WITH r AS (
  SELECT 'BBM' AS ds, jenis_bbm AS k1, '' AS k2, valid_from::date AS vf, COALESCE(valid_to::date, DATE '9999-12-31') AS vt, is_current
  FROM raw.ref_bbm_esdm
  UNION ALL
  SELECT 'HET/HAP', komoditas, COALESCE(varian_mutu,''), valid_from::date, COALESCE(valid_to::date, DATE '9999-12-31'), is_current
  FROM raw.ref_bapanas_het)
SELECT 'P5' AS profil, 'rentang_terbalik' AS cek, COUNT(*) AS pelanggaran FROM r WHERE vf > vt
UNION ALL SELECT 'P5', 'periode_tumpang_tindih', COUNT(*) FROM r a JOIN r b
  ON a.ds=b.ds AND a.k1=b.k1 AND a.k2=b.k2 AND (a.vf,a.vt) < (b.vf,b.vt) AND a.vt >= b.vf
UNION ALL SELECT 'P5', 'kunci_tanpa_atau_lebih_dari_1_current', COUNT(*) FROM (
  SELECT ds,k1,k2 FROM r GROUP BY 1,2,3 HAVING COUNT(*) FILTER (WHERE is_current) <> 1) x;
