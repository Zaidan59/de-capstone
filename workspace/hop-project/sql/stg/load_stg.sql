-- Standalone SQL staging load (PR #2 baseline; distinct from active Hop stg.weather_daily)
BEGIN;
CREATE TEMP TABLE _ctx ON COMMIT DROP AS
  SELECT max(run_id) AS run_id FROM ops.pipeline_runs WHERE pipeline_name = 'wf_ingest_all_sources';
TRUNCATE stg.price_pihps, stg.price_dki_monthly, stg.price_info_pangan_jkt, stg.weather_openmeteo,
         stg.bmkg_forecast, stg.fx_usd_idr, stg.hbkn_calendar,
         stg.ref_bbm_esdm, stg.ref_bapanas_het, stg.ref_supply_corridor;
-- PIHPS pasar tradisional dan modern (SRC-01/02): unpivot 3 wilayah
INSERT INTO stg.price_pihps (source_id, market_tier, commodity_key, price_date, region_key, price_rp, run_id, raw_ingested_at)
SELECT 'SRC-01/02', lower(trim(m.market_tier)), lower(trim(m.commodity)), stg.safe_date(m.date_param),
       v.region_key, round(v.val::numeric, 2), (SELECT run_id FROM _ctx), m.ingested_at
FROM raw.pihps_market_prices m
CROSS JOIN LATERAL (VALUES ('DKI', m.dki_jakarta), ('JABAR', m.jawa_barat), ('JATENG', m.jawa_tengah)) AS v(region_key, val);
-- PIHPS produsen (SRC-03): unpivot 2 wilayah
INSERT INTO stg.price_pihps (source_id, market_tier, commodity_key, price_date, region_key, price_rp, run_id, raw_ingested_at)
SELECT 'SRC-03', 'produsen', lower(trim(p.commodity)), stg.safe_date(p.date_param),
       v.region_key, round(v.val::numeric, 2), (SELECT run_id FROM _ctx), p.ingested_at
FROM raw.pihps_produsen_prices p
CROSS JOIN LATERAL (VALUES ('JABAR', p.jawa_barat), ('JATENG', p.jawa_tengah)) AS v(region_key, val);
-- Harga DKI bulanan (SRC-04)
INSERT INTO stg.price_dki_monthly (source_id, period_month, region_name, commodity_raw, commodity_std, price_raw, price_rp, price_status, run_id, raw_ingested_at)
SELECT 'SRC-04', stg.safe_month(periode_data), trim(wilayah), trim(komoditas),
       regexp_replace(regexp_replace(upper(trim(komoditas)), '\s+', ' ', 'g'), '^(BERAS MUNCUL) \.I$', '\1 I'),
       harga_raw, stg.safe_num(harga_raw),
       CASE WHEN harga_raw IS NULL OR trim(harga_raw) = '' THEN 'EMPTY'
            WHEN stg.safe_num(harga_raw) IS NULL THEN 'NON_NUMERIC'
            WHEN stg.safe_num(harga_raw) <= 0 THEN 'NONPOSITIVE'
            ELSE 'OK' END,
       (SELECT run_id FROM _ctx), ingested_at
FROM raw.dki_harga_pokok_bulanan;
-- Info Pangan Jakarta (SRC-04)
INSERT INTO stg.price_info_pangan_jkt (source_id, period_year, commodity_std, price_raw, price_rp, run_id, raw_ingested_at)
SELECT 'SRC-04', CASE WHEN trim(periode_data) ~ '^[0-9]{4}(\.0+)?$' THEN substr(trim(periode_data),1,4)::int END,
       regexp_replace(upper(trim(komoditas)), '\s+', ' ', 'g'), harga_rata_rata_raw, stg.safe_num(replace(harga_rata_rata_raw, ',', '')),
       (SELECT run_id FROM _ctx), ingested_at
FROM raw.info_pangan_jkt;
-- Cuaca harian: arsip + live (SRC-05..07)
INSERT INTO stg.weather_openmeteo (source_id, region_key, weather_date, temp_max_c, precip_mm, rain_mm, data_origin, http_status, run_id, raw_ingested_at)
SELECT CASE WHEN r.region_key IN ('garut','magelang') THEN 'SRC-05'
            WHEN r.region_key IN ('karawang','indramayu') THEN 'SRC-06'
            WHEN r.region_key IN ('brebes','dki_jakarta') THEN 'SRC-07'
            ELSE 'SRC-05..07' END,
       r.region_key, stg.safe_date(r.weather_date),
       round(r.temp::numeric, 2), round(r.precip::numeric, 2), round(r.rain::numeric, 2),
       r.origin, r.http_status, (SELECT run_id FROM _ctx), r.ingested_at
FROM (
  SELECT regexp_replace(lower(trim(source_file)), '^cuaca\s+|\.csv$', '', 'g') AS region_key, weather_date,
         temperature_2m_max_c AS temp, precipitation_sum_mm AS precip, rain_sum_mm AS rain,
         'archive'::text AS origin, NULL::int AS http_status, ingested_at
  FROM raw.openmeteo_archive
  UNION ALL
  SELECT lower(trim(region_key)), weather_date, temperature_2m_max_c, precipitation_sum_mm, rain_sum_mm,
         'live'::text, http_status, ingested_at
  FROM raw.openmeteo_live
) r;
-- BMKG prakiraan (SRC-08)
INSERT INTO stg.bmkg_forecast (source_id, region_key, adm4_code, regency_name, local_datetime, utc_datetime, temp_c, humidity_pct, rain_mm, wind_kmh, cloud_pct, weather_code, weather_desc, http_status, run_id, raw_ingested_at)
SELECT 'SRC-08', lower(trim(region_key)), adm4_code, kotkab, stg.safe_ts(local_datetime), stg.safe_ts(utc_datetime),
       t_celsius, hu_pct, tp_mm, ws_kmh, tcc_pct, weather_code, weather_desc, http_status, (SELECT run_id FROM _ctx), ingested_at
FROM raw.bmkg_forecast;
-- Kurs USD/IDR (SRC-09)
INSERT INTO stg.fx_usd_idr (source_id, rate_date, base_currency, quote_currency, usd_idr_rate, source_api, run_id, raw_ingested_at)
SELECT 'SRC-09', stg.safe_date(rate_date), upper(trim(base_currency)), upper(trim(quote_currency)),
       round(usd_idr_rate::numeric, 4), source_api, (SELECT run_id FROM _ctx), ingested_at
FROM raw.fx_usd_idr;
-- Kalender libur dan HBKN (SRC-13)
INSERT INTO stg.hbkn_calendar (source_id, holiday_date, holiday_year, local_name, name_en, hbkn_category, is_hbkn_major, is_fixed, is_global, run_id, raw_ingested_at)
SELECT 'SRC-13', stg.safe_date(holiday_date), year, local_name, name, hbkn_category, is_hbkn_major, fixed, global_holiday,
       (SELECT run_id FROM _ctx), ingested_at
FROM raw.hbkn_calendar;
-- Referensi BBM (SRC-10)
INSERT INTO stg.ref_bbm_esdm (source_id, bbm_id, fuel_type, fuel_category, price_per_liter, regulation_basis, valid_from, valid_to, is_current, run_id, raw_ingested_at)
SELECT 'SRC-10', bbm_id, trim(jenis_bbm), trim(kategori_bbm), round(harga_per_liter::numeric, 2), dasar_regulasi,
       stg.safe_date(valid_from), stg.safe_date(valid_to), is_current, (SELECT run_id FROM _ctx), ingested_at
FROM raw.ref_bbm_esdm;
-- Referensi HET/HAP (SRC-11)
INSERT INTO stg.ref_bapanas_het (source_id, reg_id, commodity_raw, quality_variant, limit_type, lower_limit_rp, upper_limit_rp, regulation_basis, valid_from, valid_to, is_current, run_id, raw_ingested_at)
SELECT 'SRC-11', reg_id, trim(komoditas), trim(varian_mutu), trim(jenis_batas),
       round(batas_bawah_rp::numeric, 2), round(batas_atas_rp::numeric, 2), dasar_regulasi,
       stg.safe_date(valid_from), stg.safe_date(valid_to), is_current, (SELECT run_id FROM _ctx), ingested_at
FROM raw.ref_bapanas_het;
-- Referensi koridor pasokan (SRC-12), status verifikasi ikut dibawa
INSERT INTO stg.ref_supply_corridor (source_id, corridor_id, commodity_code, commodity_raw, region_code, regency_name, province_name, destination_market, latitude, longitude, corridor_type, verification_status, active_for_join, contribution_weight, weight_scope, weight_period, run_id, raw_ingested_at)
SELECT 'SRC-12', corridor_id, commodity_code, trim(komoditas), region_code, trim(kabupaten_sentra), trim(provinsi_sentra),
       trim(pasar_tujuan), latitude_ref, longitude_ref, corridor_type, verification_status, active_for_join,
       bobot_kontribusi_pasokan, bobot_scope, bobot_period, (SELECT run_id FROM _ctx), ingested_at
FROM raw.ref_supply_corridor;
COMMIT;

