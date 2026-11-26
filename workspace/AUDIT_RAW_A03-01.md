# Audit Pasca-Ingestion (A03-01)
- PIC: Muhammad Ghalib Rafiqi
- Waktu audit: 2026-11-26 02:03
- Versi repo (git commit): a532576
- Run ingestion: run_id 2, pipeline wf_ingest_all_sources, status SUCCESS, rows_processed 35.888
- Catatan: run_id 1 (seed-demo) adalah data sintetis bootstrap, bukan ingestion nyata.
- Query: workspace/hop-project/sql/a03_01_raw_audit.sql dan a03_01_query4_safe.sql
- Output mentah: workspace/evidence/a03_01_audit_output.txt dan a03_01_query4_fix.txt (di drive bersama)
## 1. Ringkasan per sumber
| Source ID | Tabel raw | Diharapkan | Aktual | Delta | Rentang data | Status |
|---|---|---|---|---|---|---|
| SRC-01/02 | raw.pihps_market_prices | 14.544 | 14.544 | 0 | 2022-01-01 s/d 2026-02-12 | OK |
| SRC-03 | raw.pihps_produsen_prices | 5.972 | 5.972 | 0 | 2022-01-01 s/d 2026-02-12 | OK |
| SRC-04 | raw.dki_harga_pokok_bulanan | 4.725 | 4.725 | 0 | 202501 s/d 202609 | OK |
| SRC-04 | raw.info_pangan_jkt | 33 | 33 | 0 | 2023 s/d 2025 | OK |
| SRC-05..07 | raw.openmeteo_archive | 9.024 | 9.024 | 0 | 2022-01-01 s/d 2026-02-12 | OK |
| SRC-05..07 | raw.openmeteo_live | 60 | 60 | 0 | 2026-11-19 s/d 2026-11-28 | OK |
| SRC-08 | raw.bmkg_forecast | 120 | 108 | -12 | 2026-11-26 02:00 s/d 2026-11-28 05:00 | CEK |
| SRC-09 | raw.fx_usd_idr | 1.250 | 1.250 | 0 | 2021-12-31 s/d 2026-11-18 | OK |
| SRC-10 | raw.ref_bbm_esdm | 4 | 4 | 0 | valid_from 2022-01-01 s/d 2022-09-03 | OK |
| SRC-11 | raw.ref_bapanas_het | 12 | 12 | 0 | valid_from 2022-01-01 s/d 2025-08-22 | OK |
| SRC-12 | raw.ref_supply_corridor | 9 | 9 | 0 | COR-01 s/d COR-09 | OK |
| SRC-13 | raw.hbkn_calendar | 147 | 147 | 0 | 2022-01-01 s/d 2026-12-31 | OK |
Hasil: 13 Source ID terbaca lewat 12 tabel raw (kriteria minimal 8 sumber terpenuhi). 11 tabel cocok dengan manifest, 1 tabel (BMKG) selisih -12 baris. Total baris 35.888, sama dengan rows_processed di ops.pipeline_runs.
## 2. Hasil Query 4 (harga DKI bulanan, SRC-04)
| Ukuran | Nilai |
|---|---|
| Jumlah baris | <4725> |
| Jumlah bulan | <21> |
| Jumlah wilayah | <5> |
| Jumlah nama komoditas | <46> |
| Harga kosong | <0> |
| Harga non-numerik (mis. N/A) | <248> |
| Harga nol atau negatif | <2> |
Nilai non-angka yang ditemukan: <248>
## 3. Temuan
1. raw.bmkg_forecast hanya 108 baris dari 120 yang diharapkan. Sumbernya API prakiraan live, jadi jumlah baris bisa berubah tiap run. Run tetap berstatus SUCCESS, artinya status SUCCESS belum mendeteksi selisih ini.
2. Kolom harga_raw di raw.dki_harga_pokok_bulanan memuat teks non-angka (mis. N/A), sehingga cast langsung ke numeric gagal. Kolom ini harus dibersihkan di staging dan dicek lewat rule DQ.
3. Data historis harga PIHPS dan arsip cuaca berhenti di 2026-02-12, sedangkan data live cuaca dan BMKG sampai akhir November 2026. Tidak ada data harga setelah 2026-02-12.
4. Jumlah baris PIHPS pasar tradisional (1.415 sampai 1.417 per seri) lebih sedikit dari modern dan produsen (1.493 per seri), padahal rentang tanggalnya sama (1.504 hari kalender). Detail hari kosong dihitung di profiling P1 (A03-06).
5. raw.ref_bbm_esdm hanya 4 baris dengan valid_from terakhir 2022-09-03. Kelengkapan riwayat harga BBM perlu diverifikasi terhadap sumber ESDM sebelum dipakai di KPI risiko.
6. raw.ref_supply_corridor berisi 9 koridor (COR-01 s/d COR-09), data_version fdp-2024-v1. Koridor belum diverifikasi, jadi bobot kontribusi tidak boleh diklaim sebagai data riil.
7. Pemeriksaan kolom wajib pada audit ini terbatas pada NULL harga PIHPS (0 NULL di semua seri) dan NULL curah hujan (0 NULL di 6 file cuaca, maksimum 84,4 mm di Garut).
## 4. Kendala selama audit
- Ingestion pertama gagal di action Ensure raw tables dengan error password authentication failed for user labuser. Diperbaiki dengan menyamakan password database dengan .env, lalu ingestion diulang dan berhasil (run_id 2).
## 5. Langkah selanjutnya
- A03-06: desain 10 rule DQ dengan baseline dari profiling.
- A03-08: staging, termasuk normalisasi harga_raw DKI.
