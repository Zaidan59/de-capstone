CREATE NAMESPACE IF NOT EXISTS lab.demo;
CREATE TABLE IF NOT EXISTS lab.demo.sales (
  order_id STRING, source_system STRING, amount DECIMAL(14,2), ordered_date DATE
) USING iceberg;
INSERT INTO lab.demo.sales VALUES
('SIM-001','ODOO',100000.00,DATE '2026-09-01'),
('SIM-002','PRESTASHOP',250000.00,DATE '2026-09-02');
SELECT * FROM lab.demo.sales;
SELECT snapshot_id,committed_at FROM lab.demo.sales.snapshots ORDER BY committed_at;
ALTER TABLE lab.demo.sales ADD COLUMN sales_channel STRING;
INSERT INTO lab.demo.sales VALUES('SIM-003','ODOO',30000.00,DATE '2026-09-03','WEB');
SELECT snapshot_id,committed_at FROM lab.demo.sales.snapshots ORDER BY committed_at;
-- Time travel: replace <snapshot_id> with a value from snapshots.
-- SELECT * FROM lab.demo.sales VERSION AS OF <snapshot_id>;
