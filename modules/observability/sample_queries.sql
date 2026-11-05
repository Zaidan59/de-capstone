SELECT pipeline_name,started_at,completed_at,status,rows_processed
FROM ops.pipeline_runs ORDER BY started_at DESC LIMIT 20;
SELECT source_system,sum(order_count) AS order_count,sum(net_amount) AS net_amount
FROM mart.daily_sales GROUP BY source_system;
SELECT now()-max(completed_at) AS last_success_age
FROM ops.pipeline_runs WHERE status='SUCCESS';
