\set ON_ERROR_STOP on

CREATE SCHEMA IF NOT EXISTS migration_demo;

CREATE TABLE IF NOT EXISTS migration_demo.orders (
    order_id BIGINT PRIMARY KEY,
    customer_ref TEXT NOT NULL,
    amount NUMERIC(10,2) NOT NULL,
    status TEXT NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO migration_demo.orders
    (order_id, customer_ref, amount, status)
SELECT
    n,
    'CUSTOMER-' || LPAD(n::text, 4, '0'),
    (n * 1.25)::numeric(10,2),
    'pending'
FROM generate_series(1, 1000) AS n
ON CONFLICT (order_id) DO NOTHING;

SELECT
    count(*) AS total_rows,
    sum(amount) AS total_amount,
    min(order_id) AS first_id,
    max(order_id) AS last_id
FROM migration_demo.orders;

SHOW wal_level;
SHOW max_wal_senders;
