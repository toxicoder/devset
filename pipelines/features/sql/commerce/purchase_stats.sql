-- Purchase Stats Feature Pipeline
-- Target: company.features.v1.PurchaseStats
-- Granularity: One row per entity_id (user or merchant)

WITH orders AS (
    SELECT
        user_id AS entity_id,
        order_id,
        order_amount_micros,
        currency_code,
        created_at
    FROM
        raw.orders
    WHERE
        status = 'COMPLETED'
)

SELECT
    o.entity_id,
    -- Total Lifetime Spend (simplified to base currency)
    STRUCT(
        SUM(o.order_amount_micros) AS units, -- Proto Money uses units/nanos, simplified here
        'USD' AS currency_code
    ) AS total_lifetime_spend,
    -- Total Order Count
    COUNT(o.order_id) AS total_order_count,
    -- Average Order Value
    STRUCT(
        AVG(o.order_amount_micros) AS units,
        'USD' AS currency_code
    ) AS average_order_value,
    -- Days since last purchase
    DATE_DIFF(CURRENT_DATE(), DATE(MAX(o.created_at)), DAY) AS days_since_last_purchase,
    -- Max Single Purchase
    STRUCT(
        MAX(o.order_amount_micros) AS units,
        'USD' AS currency_code
    ) AS max_single_purchase,
    CURRENT_TIMESTAMP() AS feature_timestamp
FROM
    orders o
GROUP BY
    o.entity_id;
