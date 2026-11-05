CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS stg;
CREATE SCHEMA IF NOT EXISTS dq;
CREATE SCHEMA IF NOT EXISTS mart;
CREATE SCHEMA IF NOT EXISTS ops;
CREATE SCHEMA IF NOT EXISTS semantic;
CREATE SCHEMA IF NOT EXISTS mdm;

CREATE TABLE IF NOT EXISTS raw.sales_orders (
 order_id text PRIMARY KEY, source_system text NOT NULL,
 customer_id text NOT NULL, product_id text NOT NULL,
 quantity integer NOT NULL, unit_price numeric(12,2) NOT NULL,
 status text NOT NULL, ordered_at timestamptz NOT NULL,
 updated_at timestamptz NOT NULL
);
CREATE TABLE IF NOT EXISTS stg.sales_orders (
 order_id text PRIMARY KEY, source_system text NOT NULL,
 customer_id text NOT NULL, product_id text NOT NULL,
 quantity integer NOT NULL, unit_price numeric(12,2) NOT NULL,
 amount numeric(14,2) NOT NULL, status text NOT NULL,
 ordered_at timestamptz NOT NULL, loaded_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS dq.quality_issues(
 issue_id bigserial PRIMARY KEY, run_id text, order_id text,
 rule_id text NOT NULL, severity text NOT NULL, reason text,
 detected_at timestamptz NOT NULL DEFAULT now(), resolution_status text DEFAULT 'OPEN'
);
CREATE TABLE IF NOT EXISTS ops.pipeline_runs(
 run_id bigserial PRIMARY KEY, pipeline_name text NOT NULL,
 started_at timestamptz NOT NULL DEFAULT now(), completed_at timestamptz,
 status text NOT NULL, rows_processed bigint, message text
);
CREATE TABLE IF NOT EXISTS mdm.asset_identity_crosswalk(
 source_system text NOT NULL, source_asset_id text NOT NULL,
 canonical_asset_id text, match_method text, review_status text DEFAULT 'PENDING',
 reviewed_at timestamptz,
 PRIMARY KEY (source_system,source_asset_id)
);
CREATE TABLE IF NOT EXISTS mart.daily_sales(
 sales_date date NOT NULL,source_system text NOT NULL,
 order_count bigint NOT NULL, net_amount numeric(16,2) NOT NULL,
 PRIMARY KEY(sales_date,source_system)
);
CREATE OR REPLACE VIEW semantic.v_daily_sales AS
SELECT sales_date, source_system, order_count, net_amount
FROM mart.daily_sales;
CREATE OR REPLACE VIEW semantic.v_data_quality AS
SELECT severity, count(*)::integer AS issue_count FROM dq.quality_issues GROUP BY severity;
