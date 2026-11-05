INSERT INTO raw.sales_orders(order_id,source_system,customer_id,product_id,quantity,unit_price,status,ordered_at,updated_at)
SELECT 'ORD-' || LPAD(g::text,3,'0'),
       CASE WHEN g%2=0 THEN 'PRESTASHOP' ELSE 'ODOO' END,
       'CUS-' || LPAD((g%12+1)::text,3,'0'),
       'PROD-' || LPAD((g%9+1)::text,3,'0'),
       (g%4+1), (g%11+1)*12500,
       CASE WHEN g%13=0 THEN 'CANCELLED' ELSE 'CONFIRMED' END,
       timestamptz '2026-08-01 08:00+07' + (g || ' hours')::interval,
       timestamptz '2026-08-01 08:00+07' + (g || ' hours')::interval
FROM generate_series(1,60) g ON CONFLICT(order_id) DO NOTHING;

INSERT INTO stg.sales_orders(order_id,source_system,customer_id,product_id,quantity,unit_price,amount,status,ordered_at)
SELECT order_id,source_system,customer_id,product_id,quantity,unit_price,
       quantity*unit_price,status,ordered_at FROM raw.sales_orders
ON CONFLICT(order_id) DO UPDATE SET amount=EXCLUDED.amount, status=EXCLUDED.status, loaded_at=now();

INSERT INTO mart.daily_sales(sales_date,source_system,order_count,net_amount)
SELECT ordered_at::date,source_system,count(*),sum(amount)
FROM stg.sales_orders WHERE status='CONFIRMED'
GROUP BY ordered_at::date,source_system
ON CONFLICT(sales_date,source_system) DO UPDATE
 SET order_count=EXCLUDED.order_count,net_amount=EXCLUDED.net_amount;

INSERT INTO ops.pipeline_runs(pipeline_name,status,completed_at,rows_processed,message)
VALUES('seed-demo','SUCCESS',now(),60,'Synthetic bootstrap, not a real production run');
