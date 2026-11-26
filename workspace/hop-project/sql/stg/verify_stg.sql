WITH c(cek, expected, actual) AS (VALUES
 ('price_pihps market x3',  (SELECT count(*)*3 FROM raw.pihps_market_prices),   (SELECT count(*) FROM stg.price_pihps WHERE source_id='SRC-01/02')),
 ('price_pihps produsen x2',(SELECT count(*)*2 FROM raw.pihps_produsen_prices), (SELECT count(*) FROM stg.price_pihps WHERE source_id='SRC-03')),
 ('price_dki_monthly',      (SELECT count(*) FROM raw.dki_harga_pokok_bulanan), (SELECT count(*) FROM stg.price_dki_monthly)),
 ('price_info_pangan_jkt',  (SELECT count(*) FROM raw.info_pangan_jkt),         (SELECT count(*) FROM stg.price_info_pangan_jkt)),
 ('weather_daily',          (SELECT (SELECT count(*) FROM raw.openmeteo_archive)+(SELECT count(*) FROM raw.openmeteo_live)), (SELECT count(*) FROM stg.weather_daily)),
 ('bmkg_forecast',          (SELECT count(*) FROM raw.bmkg_forecast),           (SELECT count(*) FROM stg.bmkg_forecast)),
 ('fx_usd_idr',             (SELECT count(*) FROM raw.fx_usd_idr),              (SELECT count(*) FROM stg.fx_usd_idr)),
 ('hbkn_calendar',          (SELECT count(*) FROM raw.hbkn_calendar),           (SELECT count(*) FROM stg.hbkn_calendar)),
 ('ref_bbm_esdm',           (SELECT count(*) FROM raw.ref_bbm_esdm),            (SELECT count(*) FROM stg.ref_bbm_esdm)),
 ('ref_bapanas_het',        (SELECT count(*) FROM raw.ref_bapanas_het),         (SELECT count(*) FROM stg.ref_bapanas_het)),
 ('ref_supply_corridor',    (SELECT count(*) FROM raw.ref_supply_corridor),     (SELECT count(*) FROM stg.ref_supply_corridor)))
SELECT cek, expected, actual, actual-expected AS delta, CASE WHEN actual=expected THEN 'OK' ELSE 'CEK' END AS status FROM c;
SELECT 'tanggal NULL price_pihps' AS cek, count(*) AS n FROM stg.price_pihps WHERE price_date IS NULL
UNION ALL SELECT 'periode NULL dki', count(*) FROM stg.price_dki_monthly WHERE period_month IS NULL
UNION ALL SELECT 'tanggal NULL weather', count(*) FROM stg.weather_daily WHERE weather_date IS NULL
UNION ALL SELECT 'waktu NULL bmkg', count(*) FROM stg.bmkg_forecast WHERE local_datetime IS NULL
UNION ALL SELECT 'tanggal NULL fx', count(*) FROM stg.fx_usd_idr WHERE rate_date IS NULL
UNION ALL SELECT 'tanggal NULL hbkn', count(*) FROM stg.hbkn_calendar WHERE holiday_date IS NULL
UNION ALL SELECT 'valid_from NULL ref', (SELECT count(*) FROM stg.ref_bbm_esdm WHERE valid_from IS NULL)+(SELECT count(*) FROM stg.ref_bapanas_het WHERE valid_from IS NULL)
UNION ALL SELECT 'harga NULL info_pangan', count(*) FROM stg.price_info_pangan_jkt WHERE price_rp IS NULL
UNION ALL SELECT 'run_id NULL (semua tabel harga)', count(*) FROM stg.price_pihps WHERE run_id IS NULL;
SELECT price_status, count(*) AS n FROM stg.price_dki_monthly GROUP BY 1 ORDER BY 1;
SELECT count(DISTINCT commodity_raw) AS nama_raw, count(DISTINCT commodity_std) AS nama_std FROM stg.price_dki_monthly;
SELECT data_origin, source_id, region_key, count(*) AS n FROM stg.weather_daily GROUP BY 1,2,3 ORDER BY 1,3;
