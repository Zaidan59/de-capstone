# DQ Rule Matrix (A03-06)

* PIC: Muhammad Ghalib Rafiqi
* Waktu: 2026-11-26 11:42
* Versi repo: 8d97a0f
* Baseline dihitung dari tabel raw hasil run\_id 2 (wf\_ingest\_all\_sources, 26 Nov 2026)
* Query: workspace/hop-project/sql/a03\_01\_raw\_audit.sql, a03\_01\_query4\_safe.sql, a03\_06\_profiling.sql
* Output mentah: workspace/evidence/a03\_06\_profiling\_output.txt dan a03\_06\_dq\_baseline\_output.txt (di drive tim)

## Matriks rule

|Rule|Dataset|Dimensi|Kondisi lulus|Baseline (observed)|Severity|Ambang lulus|Aksi gagal|
|-|-|-|-|-|-|-|-|
|DQ-01|stg harga PIHPS dan DKI|Completeness|harga tidak NULL, tidak kosong, dan berupa angka|PIHPS 0 NULL (market dan produsen). DKI: kosong 0, non-numerik (teks N/A) 248 dari 4.725 baris (5,25%), terisi valid 94,75%|HIGH|PIHPS 100%, DKI >= 95%|QUARANTINE|
|DQ-02|stg harga PIHPS dan DKI|Validity|harga > 0|PIHPS 0 baris harga <= 0. DKI 2 baris nol (keduanya SUSU BUBUK BENDERA 400GR)|CRITICAL|100%|QUARANTINE|
|DQ-03|harga, cuaca, DKI|Uniqueness|kunci bisnis unik|Kunci duplikat: market 0, produsen 0, cuaca arsip 0, DKI bulanan 0|CRITICAL|100%|QUARANTINE (simpan yang pertama)|
|DQ-04|semua dataset bertanggal|Validity|tanggal valid, 2022-01-01 s/d hari ini (DKI: YYYYMM valid)|Tanggal di luar rentang: market 0, produsen 0, cuaca arsip 0. DKI bulan tidak valid 0|HIGH|>= 99,9%|QUARANTINE|
|DQ-05|stg harga PIHPS|Consistency|perubahan harian <= 300% per seri|Lonjakan > 300%: 0 dari 14534 perbandingan harian (kolom dki\_jakarta, per market\_tier dan commodity)|MEDIUM|>= 99,5%|FLAG (tetap di staging, dicatat)|
|DQ-06|stg cuaca|Validity|hujan tidak NULL dan 0-500 mm/hari|0 NULL, maksimum 84,4 mm (Garut)|MEDIUM|>= 99,9%|QUARANTINE|
|DQ-07|harga, cuaca, DKI|Referential|komoditas dan wilayah terpetakan ke kamus|DKI: beras berganti nama, BERAS MUNCUL .I 80 baris (202501 s/d 202604) lalu BERAS MUNCUL I 25 baris (202605 s/d 202609). Produsen hanya 4 dari 5 komoditas (tanpa bawang\_putih)|HIGH|100% setelah normalisasi|QUARANTINE yang tak terpetakan|
|DQ-08|stg harga PIHPS|Completeness (kalender)|seri harian tanpa hari kosong|Tradisional 87-89 dari 1.504 hari kosong (94,1-94,2% terisi). Modern 11 hari kosong (99,3%). Produsen 1.493 hari ada dari 1.504, berarti 11 kosong (dari audit Query 2)|MEDIUM|>= 95% hari terisi|FLAG (dilaporkan, tidak diisi buatan)|
|DQ-09|stg harga PIHPS|Precision|harga berupa rupiah bulat|591 nilai tak bulat dari 43.632 nilai (1,35%)|LOW|>= 98%|FLAG, dibulatkan 2 desimal di staging|
|DQ-10|ref BBM dan HET/HAP|Consistency (SCD2)|valid\_from <= valid\_to, tidak tumpang tindih, tepat 1 is\_current per kunci|Rentang terbalik 0, periode tumpang tindih 0, kunci tanpa atau lebih dari 1 current 0|HIGH|100%|QUARANTINE|

## Hasil terhadap ambang (temuan nyata, ambang tidak diturunkan)

* DQ-01 DKI: 94,75% terisi valid, di bawah ambang 95%. GAGAL tipis.
* DQ-08 tradisional: 94,1-94,2% terisi, di bawah ambang 95%. GAGAL tipis.
* DQ-09: 98,65% bulat, di atas ambang 98%. LULUS.
* DQ-10: 0 pelanggaran. LULUS.
* DQ-03: LULUS, 0 kunci duplikat di semua dataset (market 0, produsen 0, cuaca arsip 0, DKI bulanan 0).
* DQ-04: LULUS, 0 tanggal di luar rentang di semua dataset (market 0, produsen 0, cuaca arsip 0, DKI 0 bulan tidak valid).
* DQ-05: LULUS, 0 lonjakan > 300% dari 14.534 perbandingan harian (market, kolom dki\_jakarta).

## Catatan desain

1. QUARANTINE dipakai untuk baris yang tidak boleh masuk mart (rule CRITICAL dan HIGH). FLAG dipakai untuk kualitas yang cuma dilaporkan (DQ-05, DQ-08, DQ-09).
2. Ambang tidak diturunkan agar lolos. Baseline di bawah ambang dilaporkan apa adanya.
3. Kolom harga\_raw DKI bertipe teks dan berisi teks N/A (248 baris), bukan string kosong. DQ-01 dan DQ-02 memperlakukan teks non-angka sebagai harga tidak valid, dan cast ke numeric harus dilakukan dengan pola regex terlebih dahulu.
4. periode\_data DKI tersimpan dengan akhiran .0 (contoh 202501.0). Staging harus membersihkannya sebelum dijadikan tanggal.
5. Rule BMKG kode sensor 8888/9999 di proposal belum dapat didemokan. Endpoint BMKG yang dipakai adalah prakiraan (punya weather\_code), bukan data observasi. Jika rule tetap dipertahankan, harus dilabeli simulasi.
6. Produsen tidak punya komoditas bawang\_putih (4 dari 5 komoditas), sehingga margin bawang putih produsen ke pasar tidak dapat dihitung dari data ini.
7. DQ-05 dihitung pada kolom dki\_jakarta per seri (market\_tier, commodity).
8. Data harga PIHPS dan arsip cuaca berhenti di 2026-02-12, sehingga DQ-04 tidak menguji data setelah tanggal itu.

