-- Cart Metrics Feature Pipeline
-- Target: company.features.v1.CartMetrics
-- Granularity: One row per entity_id

WITH cart_activity AS (
    SELECT
        user_id AS entity_id,
        session_id,
        cart_id,
        COUNT(item_id) as items_in_cart,
        MIN(added_at) as first_add_ts,
        MAX(checkout_completed_at) as checkout_ts,
        status -- ABANDONED, COMPLETED
    FROM
        derived.cart_sessions
    GROUP BY
        user_id, session_id, cart_id, status
),

abandoned_items AS (
    SELECT
        user_id,
        category
    FROM
        derived.cart_items
    WHERE
        status = 'ABANDONED'
)

SELECT
    ca.entity_id,
    -- Cart Abandonment Rate
    SAFE_DIVIDE(
        COUNT(CASE WHEN ca.status = 'ABANDONED' THEN 1 END),
        COUNT(ca.cart_id)
    ) AS cart_abandonment_rate,
    -- Avg items per cart
    AVG(ca.items_in_cart) AS avg_items_per_cart,
    -- Avg time to checkout
    AVG(TIMESTAMP_DIFF(ca.checkout_ts, ca.first_add_ts, SECOND)) AS avg_time_to_checkout_seconds,
    -- Frequent Abandoned Category (Mode)
    (SELECT category FROM abandoned_items ai WHERE ai.user_id = ca.entity_id GROUP BY category ORDER BY COUNT(*) DESC LIMIT 1) AS frequent_abandoned_category,
    CURRENT_TIMESTAMP() AS feature_timestamp
FROM
    cart_activity ca
GROUP BY
    ca.entity_id;
