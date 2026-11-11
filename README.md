# Capstone Project Data Engineering — GROUP A03

> **Pembangunan Data Mart Terintegrasi untuk Pemantauan Dinamika Harga Pangan dan Anomali Cuaca Sentra Pemasok (Koridor Jawa Barat – DKI Jakarta)**  
> Mata Kuliah: Data Engineering (S1 Sistem Informasi) — Edisi 2026

---

## 👥 Tim Penyusun (GROUP A03)

| NIM | Nama | Role / Tanggung Jawab |
| :--- | :--- | :--- |
| **2410512043** | Muhammad Zaidan | G1: Proposal & Source Feasibility Lead |
| **2410512060** | Fia Dwi Agustina | G2 & G7: Architecture, Contracts & Final Demo |
| **2410512074** | Fadjar Malik Fadhilah | G6: Orchestration, Incident & Recovery |
| **2410512075** | Muhammad Ghalib Rafiqi | G3 & G4: Ingestion, Quality Tests & Scorecard |
| **2410512087** | Imam Hermawan Putra | G5: Data Modeling, KPIs & Governance |

---

## 🚀 Panduan Mulai Cepat (Quickstart untuk Tim)

Ikuti langkah di bawah ini setelah melakukan `git clone` di komputer masing-masing.

### 1. Prasyarat Sistem
- **Docker Desktop** (dengan WSL2 aktif untuk Windows) atau **Docker Engine + Docker Compose** (Linux/macOS).
- **RAM minimal**: 8–16 GB disarankan.
- Koneksi internet stabil untuk download image pada eksekusi pertama.

### 2. Clone Repository
```bash
git clone https://github.com/Zaidan59/de-capstone.git
cd de-capstone
```

### 3. Inisialisasi Environment (`.env`)
Generate file konfigurasi `.env` dengan password acak lokal yang aman:
- **Linux / Git Bash (Windows)**:
  ```bash
  bash scripts/lab.sh init
  ```
- **PowerShell (Windows)**:
  ```powershell
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\lab.ps1 init
  ```
> **Catatan**: File `.env` bersifat privat di komputer masing-masing dan **tidak boleh di-commit** ke Git.

### 4. Nyalakan Layanan Inti (`up core`)
Menjalankan PostgreSQL 16, MySQL 8.4, CloudBeaver, dan Webtop Workbench:
- **Linux / Git Bash**:
  ```bash
  bash scripts/lab.sh up core
  ```
- **PowerShell**:
  ```powershell
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\lab.ps1 up core
  ```

### 5. Verifikasi Instalasi (`preflight`)
Pastikan semua kontainer berjalan dan seed database berhasil:
- **Linux / Git Bash**:
  ```bash
  bash scripts/lab.sh preflight
  ```
- **PowerShell**:
  ```powershell
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\lab.ps1 preflight
  ```

---

## 🖥️ Akses Aplikasi & Tools

Setelah kontainer berjalan, akses layanan melalui browser:

| Aplikasi / Service | URL / Host Port | Kredensial & Keterangan |
| :--- | :--- | :--- |
| **Workbench Desktop** | [https://localhost:3001/](https://localhost:3001/) | Desktop browser XFCE (Apache Hop GUI, VSCodium, Terminal).<br>• **User**: `student`<br>• **Password**: cek `grep WEBTOP_PASSWORD .env`<br>*(Abaikan peringatan browser self-signed SSL)* |
| **CloudBeaver (SQL Client)** | [http://localhost:8978/](http://localhost:8978/) | SQL client web mirip DBeaver. Setup admin saat first-run. |
| **PostgreSQL** | `localhost:55432` | DB: `labdata`, User: `labuser`, Password: cek di `.env` |
| **MySQL** | `localhost:53306` | DB: `labsource`, User: `labmysql`, Password: cek di `.env` |

> [!TIP]
> **Koneksi Database di CloudBeaver:**
> Karena CloudBeaver berjalan di dalam Docker, gunakan hostname kontainer:
> - **PostgreSQL**: Host: `postgres` | Port: `5432` | DB: `labdata`
> - **MySQL**: Host: `mysql` | Port: `3306` | DB: `labsource`  
> *(Jangan gunakan `localhost` saat membuat koneksi di CloudBeaver).*

---

## 📁 Struktur Direktori

```text
de-capstone/
├── compose.yaml          # Konfigurasi multi-container Docker Compose
├── docs/                 # Dokumen proposal, manual guide, workbook, dan dataset
│   ├── 01_Capstone_Proposal_GROUP A03.docx
│   ├── 02_Capstone_Final_Report_Template.docx
│   ├── 03_Capstone_Data_and_Evidence_Workbook.xlsx
│   └── Dataset/          # Dataset mentah cuaca & harga komoditas pangan
├── scripts/
│   ├── lab.sh            # Helper script untuk Linux / Git Bash
│   └── lab.ps1           # Helper script untuk Windows PowerShell
└── workspace/            # Direktori kerja (di-mount ke dalam Workbench)
    ├── data/             # Tempat dataset yang diproses pipeline
    ├── hop-project/      # Proyek Apache Hop (.hpl, .hwf, metadata)
    ├── python/           # Script ekstraksi/transformasi Python
    └── sql/              # Script query DDL, DML, dan mart
```

---

## 🌿 Aturan Kerja Kelompok (Git Workflow)

Agar pekerjaan antar anggota tim tidak bentrok (*conflict*), ikuti aturan berikut:

1. **Tarik update terbaru sebelum bekerja**:
   ```bash
   git pull origin main
   ```
2. **Buat branch baru untuk setiap fitur/tugas**:
   ```bash
   git checkout -b feat/<nama-fitur>
   # Contoh: git checkout -b feat/ingest-cuaca-karawang
   ```
3. **Commit dan Push ke branch Anda**:
   ```bash
   git add .
   git commit -m "feat: implement data cleaning for garut weather"
   git push -u origin feat/<nama-fitur>
   ```
4. **Buka Pull Request (PR)** di GitHub:
   - Ajukan PR ke branch `main`.
   - Diskusikan dan pastikan tidak ada conflict sebelum di-merge ke `main`.

---

## 🛠️ Perintah Tambahan

- **Mematikan layanan lab**:
  ```bash
  bash scripts/lab.sh stop core
  ```
- **Melihat status kontainer**:
  ```bash
  bash scripts/lab.sh status
  ```
- **Melihat log kontainer**:
  ```bash
  bash scripts/lab.sh logs
  ```
- **Backup database PostgreSQL**:
  ```bash
  bash scripts/lab.sh backup
  ```
