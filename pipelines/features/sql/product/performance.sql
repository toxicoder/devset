CREATE TEMP FUNCTION micros_to_dollars(amount_micros FLOAT64)
RETURNS FLOAT64 AS (
    amount_micros / 1000000.0
);

-- Product Performance Feature Pipeline
-- Target: company.features.v1.ProductPerformance
-- Granularity: One row per product_id

WITH all_products AS (
    SELECT DISTINCT product_id FROM raw.products
),
sales_last_30d AS (
    SELECT
        product_id,
        SUM(quantity) AS units_sold_last_30d,
        micros_to_dollars(SUM(price_amount_micros)) AS revenue_last_30d
    FROM
        raw.order_items
    WHERE
        created_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
    GROUP BY
        product_id
),
views_last_30d AS (
    SELECT
        product_id,
        COUNT(*) AS view_count
    FROM
        raw.product_views
    WHERE
        event_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
    GROUP BY
        product_id
),
refunds_last_30d AS (
    SELECT
        product_id,
        COUNT(*) AS refund_count
    FROM
        raw.refunds
    WHERE
        created_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
    GROUP BY
        product_id
)

SELECT
    p.product_id,
    COALESCE(s.units_sold_last_30d, 0) AS units_sold_last_30d,
    SAFE_DIVIDE(COALESCE(s.units_sold_last_30d, 0), COALESCE(v.view_count, 0)) AS conversion_rate,
    COALESCE(s.revenue_last_30d, 0.0) AS revenue_last_30d,
    SAFE_DIVIDE(COALESCE(r.refund_count, 0), COALESCE(s.units_sold_last_30d, 0)) AS refund_rate,
    CURRENT_TIMESTAMP() AS feature_timestamp
FROM
    all_products p
LEFT JOIN
    sales_last_30d s ON p.product_id = s.product_id
LEFT JOIN
    views_last_30d v ON p.product_id = v.product_id
LEFT JOIN
    refunds_last_30d r ON p.product_id = r.product_id;
