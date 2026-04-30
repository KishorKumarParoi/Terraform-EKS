CREATE TABLE IF NOT EXISTS raw_sales (
    id SERIAL PRIMARY KEY,
    order_date DATE NOT NULL,
    region TEXT NOT NULL,
    product TEXT NOT NULL,
    units INTEGER NOT NULL,
    unit_price NUMERIC(10, 2) NOT NULL,
    revenue NUMERIC(12, 2) NOT NULL,
    ingested_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS sales_summary (
    snapshot_date DATE NOT NULL,
    region TEXT NOT NULL,
    total_orders INTEGER NOT NULL,
    total_units INTEGER NOT NULL,
    total_revenue NUMERIC(12, 2) NOT NULL,
    avg_order_value NUMERIC(12, 2) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (snapshot_date, region)
);
