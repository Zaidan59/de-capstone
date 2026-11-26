-- QUERY 4 (versi aman): harga DKI bulanan, tahan terhadap nilai non-numerik seperti N/A
SELECT COUNT(*) AS n, COUNT(DISTINCT periode_data) AS jumlah_bulan,
       COUNT(DISTINCT wilayah) AS jumlah_wilayah, COUNT(DISTINCT komoditas) AS nama_komoditas,
       COUNT(*) FILTER (WHERE harga_raw IS NULL OR TRIM(harga_raw) = '') AS harga_kosong,
       COUNT(*) FILTER (WHERE TRIM(harga_raw) <> '' AND TRIM(harga_raw) !~ '^-?[0-9]+(\.[0-9]+)?$') AS harga_non_numerik,
       COUNT(*) FILTER (WHERE CASE WHEN TRIM(harga_raw) ~ '^-?[0-9]+(\.[0-9]+)?$' THEN TRIM(harga_raw)::numeric END <= 0) AS harga_nol_atau_negatif
FROM raw.dki_harga_pokok_bulanan;
SELECT harga_raw, COUNT(*) AS n
FROM raw.dki_harga_pokok_bulanan
WHERE harga_raw IS NULL OR TRIM(harga_raw) !~ '^[0-9]+(\.[0-9]+)?$'
GROUP BY 1 ORDER BY 2 DESC LIMIT 10;
