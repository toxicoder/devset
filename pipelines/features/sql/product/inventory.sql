-- Product Inventory Feature Pipeline
-- Target: company.features.v1.ProductInventory
-- Granularity: One row per product_id

WITH inventory_snapshots AS (
    SELECT
        product_id,
        stock_quantity,
        snapshot_date
    FROM
        raw.inventory_snapshots
    WHERE
        snapshot_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
),
sales_velocity AS (
    SELECT
        product_id,
        SUM(quantity) / 30.0 AS avg_daily_sales_30d
    FROM
        raw.order_items
    WHERE
        created_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
    GROUP BY
        product_id
),
latest_stock AS (
    SELECT
        product_id,
        stock_quantity
    FROM
        inventory_snapshots
    WHERE
        snapshot_date = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
),
restock_events AS (
    SELECT
        product_id,
        COUNT(*) AS restock_count,
        DATE_DIFF(MAX(snapshot_date), MIN(snapshot_date), DAY) / NULLIF(COUNT(*) - 1, 0) AS avg_restock_interval_days
    FROM (
        SELECT
            product_id,
            snapshot_date,
            stock_quantity,
            LAG(stock_quantity) OVER (PARTITION BY product_id ORDER BY snapshot_date) AS prev_stock
        FROM
            inventory_snapshots
    )
    WHERE
        stock_quantity > prev_stock
    GROUP BY
        product_id
)

SELECT
    c.product_id,
    c.stock_quantity AS stock_level,
    CAST(SAFE_DIVIDE(c.stock_quantity, s.avg_daily_sales_30d) AS INT64) AS days_of_supply,
    COALESCE(r.avg_restock_interval_days, 0.0) AS restock_frequency_days,
    CASE WHEN c.stock_quantity <= 0 THEN TRUE ELSE FALSE END AS is_out_of_stock,
    CURRENT_TIMESTAMP() AS feature_timestamp
FROM
    latest_stock c
LEFT JOIN
    sales_velocity s ON c.product_id = s.product_id
LEFT JOIN
    restock_events r ON c.product_id = r.product_id;
