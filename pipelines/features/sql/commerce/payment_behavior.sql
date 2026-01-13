-- Payment Behavior Feature Pipeline
-- Target: company.features.v1.PaymentBehavior
-- Granularity: One row per entity_id

WITH payment_txns AS (
    SELECT
        user_id AS entity_id,
        payment_method, -- e.g. CreditCard, PayPal
        masked_card_number,
        is_refund,
        amount,
        txn_status,
        created_at
    FROM
        raw.transactions
),

chargebacks AS (
    SELECT
        user_id AS entity_id,
        COUNT(*) as chargeback_count
    FROM
        raw.chargebacks
    GROUP BY
        user_id
)

SELECT
    p.entity_id,
    -- Preferred Payment Method (Mode)
    (SELECT payment_method FROM payment_txns p2 WHERE p2.entity_id = p.entity_id GROUP BY payment_method ORDER BY COUNT(*) DESC LIMIT 1) AS preferred_payment_method,
    -- Unique Cards Used
    COUNT(DISTINCT p.masked_card_number) AS unique_cards_used_count,
    -- Refund Count Last 90d
    COUNT(CASE WHEN p.is_refund = TRUE AND p.created_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 90 DAY) THEN 1 END) AS refund_count_last_90d,
    -- Refund Ratio
    SAFE_DIVIDE(
        SUM(CASE WHEN p.is_refund = TRUE THEN p.amount ELSE 0 END),
        SUM(CASE WHEN p.is_refund = FALSE THEN p.amount ELSE 0 END)
    ) AS refund_ratio,
    -- Has Chargeback History
    COALESCE(c.chargeback_count, 0) > 0 AS has_chargeback_history,
    CURRENT_TIMESTAMP() AS feature_timestamp
FROM
    payment_txns p
LEFT JOIN
    chargebacks c ON p.entity_id = c.entity_id
GROUP BY
    p.entity_id, c.chargeback_count;
