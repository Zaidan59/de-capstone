#!/usr/bin/env python3
"""
Script untuk memuat dataset komoditas pangan ke MySQL database 'labsource' (sistem OLTP/Source).
Mencakup 10 komoditas pasar tradisional + 2 komoditas produsen utama (total 12 tabel sumber).
"""

import os
import glob
import pandas as pd
from sqlalchemy import create_engine

# Konfigurasi koneksi MySQL dari environment variable (di dalam container workbench)
DB_USER = os.getenv("LAB_MYSQL_USER", "labmysql")
DB_PASS = os.getenv("LAB_MYSQL_PASSWORD", "8d61235fec86a5e49bfbeae4ab9f6fa6b35e7ee582ea6f77")
DB_HOST = os.getenv("LAB_MYSQL_HOST", "mysql")
DB_PORT = os.getenv("LAB_MYSQL_PORT", "3306")
DB_NAME = os.getenv("LAB_MYSQL_DB", "labsource")

connection_url = f"mysql+pymysql://{DB_USER}:{DB_PASS}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
engine = create_engine(connection_url)

BASE_DIR = "/config/workspace/data/food_prices"
if not os.path.exists(BASE_DIR):
    BASE_DIR = os.path.expanduser("~/de-capstone/workspace/data/food_prices")

print(f"Connecting to MySQL ({DB_HOST}:{DB_PORT}/{DB_NAME}) as {DB_USER}...")

# 1. 10 Komoditas Pasar Tradisional
tradisional_files = sorted(glob.glob(f"{BASE_DIR}/pasar_tradisional/Cleaned_After_Imputation/*.csv"))

# 2. 2 Komoditas Produsen Utama (Beras & Cabai Rawit untuk disparitas produsen-konsumen)
produsen_files = [
    f"{BASE_DIR}/produsen/Cleaned_After_Imputation/final_komoditas_produsen_beras_2022_2026.csv",
    f"{BASE_DIR}/produsen/Cleaned_After_Imputation/final_komoditas_produsen_cabai_rawit_2022_2026.csv"
]

all_tasks = []
for f in tradisional_files:
    komoditas = os.path.basename(f).replace("final_komoditas_tradisional_", "").replace("_2022_2026.csv", "")
    all_tasks.append((f, f"src_tradisional_{komoditas}"))

for f in produsen_files:
    if os.path.exists(f):
        komoditas = os.path.basename(f).replace("final_komoditas_produsen_", "").replace("_2022_2026.csv", "")
        all_tasks.append((f, f"src_produsen_{komoditas}"))

print(f"Total tabel yang akan diimpor ke MySQL: {len(all_tasks)}")
print("-" * 50)

loaded_tables = []
for file_path, table_name in all_tasks:
    if not os.path.exists(file_path):
        print(f"File not found: {file_path}, skipping.")
        continue
    
    df = pd.read_csv(file_path)
    
    # Standarisasi nama kolom ke snake_case huruf kecil
    df.columns = [col.strip().lower().replace(" ", "_").replace("-", "_") for col in df.columns]
    
    # Simpan ke MySQL
    df.to_sql(name=table_name, con=engine, if_exists="replace", index=False)
    print(f"✓ Berhasil memuat {len(df)} baris ke tabel: {table_name}")
    loaded_tables.append(table_name)

print("-" * 50)
print(f"SELESAI! Sebanyak {len(loaded_tables)} tabel sumber pangan telah aktif di MySQL labsource.")
