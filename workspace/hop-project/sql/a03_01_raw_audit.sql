-- QUERY 1: ringkasan semua tabel raw vs angka manifest
WITH exp(src, tbl, expected_rows) AS (VALUES
  ('SRC-01/02','raw.pihps_market_prices',14544),
  ('SRC-03','raw.pihps_produsen_prices',5972),
  ('SRC-04','raw.info_pangan_jkt',33),
  ('SRC-04','raw.dki_harga_pokok_bulanan',4725),
  ('SRC-05..07 arsip','raw.openmeteo_archive',9024),
  ('SRC-05..07 live','raw.openmeteo_live',60),
  ('SRC-08','raw.bmkg_forecast',120),
  ('SRC-09','raw.fx_usd_idr',1250),
  ('SRC-10','raw.ref_bbm_esdm',4),
  ('SRC-11','raw.ref_bapanas_het',12),
  ('SRC-12','raw.ref_supply_corridor',9),
  ('SRC-13','raw.hbkn_calendar',147)
), act AS (
  SELECT 'raw.pihps_market_prices' tbl, COUNT(*) n, MIN(date_param) min_val, MAX(date_param) max_val, MAX(ingested_at) last_ingested FROM raw.pihps_market_prices
  UNION ALL SELECT 'raw.pihps_produsen_prices', COUNT(*), MIN(date_param), MAX(date_param), MAX(ingested_at) FROM raw.pihps_produsen_prices
  UNION ALL SELECT 'raw.info_pangan_jkt', COUNT(*), MIN(periode_data), MAX(periode_data), MAX(ingested_at) FROM raw.info_pangan_jkt
  UNION ALL SELECT 'raw.dki_harga_pokok_bulanan', COUNT(*), MIN(periode_data), MAX(periode_data), MAX(ingested_at) FROM raw.dki_harga_pokok_bulanan
  UNION ALL SELECT 'raw.openmeteo_archive', COUNT(*), MIN(weather_date), MAX(weather_date), MAX(ingested_at) FROM raw.openmeteo_archive
  UNION ALL SELECT 'raw.openmeteo_live', COUNT(*), MIN(weather_date), MAX(weather_date), MAX(ingested_at) FROM raw.openmeteo_live
  UNION ALL SELECT 'raw.bmkg_forecast', COUNT(*), MIN(local_datetime), MAX(local_datetime), MAX(ingested_at) FROM raw.bmkg_forecast
  UNION ALL SELECT 'raw.fx_usd_idr', COUNT(*), MIN(rate_date), MAX(rate_date), MAX(ingested_at) FROM raw.fx_usd_idr
  UNION ALL SELECT 'raw.ref_bbm_esdm', COUNT(*), MIN(valid_from), MAX(valid_from), MAX(ingested_at) FROM raw.ref_bbm_esdm
  UNION ALL SELECT 'raw.ref_bapanas_het', COUNT(*), MIN(valid_from), MAX(valid_from), MAX(ingested_at) FROM raw.ref_bapanas_het
  UNION ALL SELECT 'raw.ref_supply_corridor', COUNT(*), MIN(corridor_id), MAX(corridor_id), MAX(ingested_at) FROM raw.ref_supply_corridor
  UNION ALL SELECT 'raw.hbkn_calendar', COUNT(*), MIN(holiday_date), MAX(holiday_date), MAX(ingested_at) FROM raw.hbkn_calendar
)
SELECT e.src, e.tbl, e.expected_rows, a.n AS actual_rows, a.n - e.expected_rows AS delta,
       a.min_val, a.max_val, a.last_ingested,
       CASE WHEN a.n = e.expected_rows THEN 'OK' WHEN a.n = 0 THEN 'KOSONG' ELSE 'CEK' END AS status
FROM exp e LEFT JOIN act a ON a.tbl = e.tbl
ORDER BY e.src, e.tbl;

-- QUERY 2: rincian harga PIHPS
SELECT market_tier, commodity, COUNT(*) AS n, MIN(date_param) AS tgl_awal, MAX(date_param) AS tgl_akhir,
       COUNT(*) FILTER (WHERE dki_jakarta IS NULL) AS null_dki,
       COUNT(*) FILTER (WHERE jawa_barat IS NULL) AS null_jabar,
       COUNT(*) FILTER (WHERE jawa_tengah IS NULL) AS null_jateng
FROM raw.pihps_market_prices GROUP BY 1,2 ORDER BY 1,2;

SELECT commodity, COUNT(*) AS n, MIN(date_param) AS tgl_awal, MAX(date_param) AS tgl_akhir,
       COUNT(*) FILTER (WHERE jawa_barat IS NULL) AS null_jabar,
       COUNT(*) FILTER (WHERE jawa_tengah IS NULL) AS null_jateng
FROM raw.pihps_produsen_prices GROUP BY 1 ORDER BY 1;

-- QUERY 3: cuaca arsip per file (6 file x 1.504 baris)
SELECT source_file, COUNT(*) AS n, MIN(weather_date) AS tgl_awal, MAX(weather_date) AS tgl_akhir,
       COUNT(*) FILTER (WHERE precipitation_sum_mm IS NULL) AS null_hujan, MAX(precipitation_sum_mm) AS hujan_maks_mm
FROM raw.openmeteo_archive GROUP BY 1 ORDER BY 1;

-- QUERY 4: harga DKI bulanan (SRC-04)
SELECT COUNT(*) AS n, COUNT(DISTINCT periode_data) AS jumlah_bulan, COUNT(DISTINCT wilayah) AS jumlah_wilayah,
       COUNT(DISTINCT komoditas) AS nama_komoditas,
       COUNT(*) FILTER (WHERE harga_raw IS NULL OR harga_raw = '') AS harga_kosong,
       COUNT(*) FILTER (WHERE NULLIF(harga_raw,'')::numeric <= 0) AS harga_nol_atau_negatif
FROM raw.dki_harga_pokok_bulanan;

-- QUERY 5: jejak eksekusi ingestion
SELECT run_id, pipeline_name, started_at, completed_at, status, rows_processed, message
FROM ops.pipeline_runs ORDER BY run_id DESC LIMIT 5;
SELECT source_name, last_watermark, data_version, last_run_id, updated_at FROM ops.pipeline_watermarks ORDER BY source_name;