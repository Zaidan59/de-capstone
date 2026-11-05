-- DEMO ONLY, run in a disposable training database as an admin.
CREATE SCHEMA IF NOT EXISTS secure;
CREATE TABLE IF NOT EXISTS secure.department_assets(
 asset_id text PRIMARY KEY,department text,classification text
);
INSERT INTO secure.department_assets VALUES
('LAB-PC-101','FIK','INTERNAL'),('LAB-PC-102','FIK','INTERNAL'),
('ADMIN-PC-01','REKTORAT','RESTRICTED') ON CONFLICT(asset_id) DO NOTHING;
ALTER TABLE secure.department_assets ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS department_filter ON secure.department_assets;
CREATE POLICY department_filter ON secure.department_assets
USING (department = current_setting('app.department',true));
-- Test with an actual non-owner role; owner and superusers can bypass RLS.
