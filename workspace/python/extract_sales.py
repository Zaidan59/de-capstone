"""Standalone, synthetic-only example for course development in VSCodium.

Usage (inside Workbench terminal): python /config/workspace/python/extract_sales.py
"""
import os
import psycopg

with psycopg.connect(host=os.environ.get('LAB_DB_HOST','postgres'),
                     dbname=os.environ.get('LAB_DB_NAME','labdata'),
                     user=os.environ.get('LAB_DB_USER','labuser'),
                     password=os.environ['LAB_DB_PASSWORD']) as con:
    with con.cursor() as cur:
        cur.execute('SELECT source_system,COUNT(*),SUM(amount) FROM stg.sales_orders GROUP BY 1 ORDER BY 1')
        for system, n, total in cur:
            print(f'{system}: {n} orders, amount={total}')
