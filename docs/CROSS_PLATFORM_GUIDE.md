# Windows dan Linux: Petunjuk instalasi langkah demi langkah

## Windows 11 + WSL2 + Docker Desktop

1. Di Windows Features aktifkan virtualisasi/WSL2; jalankan PowerShell Admin:
   ```powershell
   wsl --install
   wsl --status
   ```
   Reboot jika diminta. Pasang Docker Desktop dari situs resmi dan pilih backend WSL2.
2. Di Docker Desktop buka Settings > Resources; untuk OpenMetadata atau Spark
   siapkan resource secukupnya (lihat Service Matrix).
3. Ekstrak paket, misalnya `C:\DE-Capstone` (hindari OneDrive/sync folder).
4. Buka PowerShell **pada folder paket**:
   ```powershell
   docker version
   docker compose version
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\lab.ps1 init
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\lab.ps1 up core
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\lab.ps1 preflight
   ```
5. `init` membuat `.env` dengan sandi acak. Jangan dikirim ke dosen atau Git.
   Buka `https://localhost:3001` dan `http://localhost:8978`.
6. **PowerShell optional profile**:
   ```powershell
   .\scripts\lab.ps1 up streaming
   .\scripts\lab.ps1 stop streaming
   ```
7. Alternatif **Git Bash** dari folder yang sama:
   ```bash
   bash scripts/lab.sh status
   bash scripts/lab.sh up bi
   bash scripts/lab.sh stop bi
   ```

*Jika muncul PowerShell execution policy block*, perintah `powershell.exe
-ExecutionPolicy Bypass -File ...` hanya berlaku untuk proses tersebut.
Tidak perlu mengubah kebijakan global PC.

**Git Bash tips:** jalankan dari folder lokal dengan path sederhana; gunakan
`bash scripts/lab.sh ...`, bukan `./scripts/lab.sh` jika mode executable file
terhapus saat ekstrak ZIP.

## Linux Ubuntu/Debian/Rocky

1. Install Docker Engine + Compose Plugin dari repositori resmi Docker untuk
   distribusi yang digunakan.
2. Pastikan:
   ```bash
   docker info
   docker compose version
   ```
3. User yang diberi akses grup docker dapat setara dengan root di host.
   Kelola izin penggunaan Docker secara hati-hati.
4. Ekstrak paket ke home user atau `/srv/de-capstone` yang writable.
5. Jalankan:
   ```bash
   bash scripts/lab.sh init
   # Opsional: sesuaikan PUID dan PGID pada .env sesuai `id -u` / `id -g`
   bash scripts/lab.sh up core
   bash scripts/lab.sh preflight
   bash scripts/lab.sh hop-demo
   ```

## Host versus container address

| Akses | Host | Port |
| --- | --- | --- |
| Dari browser Windows/Linux ke database PostgreSQL | `127.0.0.1` | `55432` |
| Dari CloudBeaver/Hop container ke database PostgreSQL | `postgres` | `5432` |
| Dari browser PC ke MySQL | `127.0.0.1` | `53306` |
| Dari CloudBeaver/Hop container ke MySQL | `mysql` | `3306` |
| Kafka dari host | `localhost` | `29092` |
| Kafka dari Flink/Hop container | `kafka` | `9092` |

Seluruh port host dapat diubah lewat `.env`, tetapi hostnames internal Compose
tetap berdasarkan nama service.

## Update/rebuild

```bash
bash scripts/lab.sh stop streaming
# Harap backup jika data penting
bash scripts/lab.sh backup
docker compose pull
bash scripts/lab.sh up core
```

Docker Compose *tidak sama* dengan server production: pertahankan local binding,
backup database, serta sanitasi secret dan data operasional.
