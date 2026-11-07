\set ON_ERROR_STOP on

BEGIN;

-- 10 new orders
INSERT INTO migration_demo.orders
    (order_id, customer_ref, amount, status)
SELECT
    n,
    'CUSTOMER-' || n,
    (n * 1.25)::numeric(10,2),
    'pending'
FROM generate_series(1001, 1010) AS n
ON CONFLICT (order_id) DO NOTHING;

-- Update five existing orders, safe against reruns
UPDATE migration_demo.orders
SET
    amount = amount + 10,
    status = 'processed',
    updated_at = now()
WHERE order_id BETWEEN 1 AND 5
  AND status = 'pending';

-- Delete five existing orders
DELETE FROM migration_demo.orders
WHERE order_id BETWEEN 996 AND 1000;

COMMIT;

SELECT
    count(*) AS total_rows,
    sum(amount) AS total_amount,
    count(*) FILTER (WHERE status = 'processed') AS processed_orders,
    count(*) FILTER (WHERE order_id BETWEEN 1001 AND 1010) AS new_orders
FROM migration_demo.orders;
