CREATE OR REPLACE VIEW semantic.v_daily_sales AS
SELECT sales_date,source_system,order_count,net_amount FROM mart.daily_sales;
SELECT source_system,sum(order_count) AS orders,sum(net_amount) AS net_sales
FROM semantic.v_daily_sales GROUP BY source_system;
