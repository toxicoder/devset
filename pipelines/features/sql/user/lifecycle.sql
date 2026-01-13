-- User Lifecycle Feature Pipeline
-- Target: company.features.v1.UserLifecycle
-- Granularity: One row per user_id

WITH churn_predictions AS (
    -- Assuming a separate ML model outputs churn scores to a table
    SELECT
        user_id,
        churn_prob,
        predicted_ltv_val,
        prediction_ts,
        ROW_NUMBER()
            OVER (PARTITION BY user_id ORDER BY prediction_ts DESC)
            AS rn
    FROM
        predictions.churn_model_output
),

user_history AS (
    SELECT
        user_id,
        created_at,
        status,
        previous_status
    FROM
        raw.users
)

SELECT
    u.user_id,
    -- Account Age
    DATE_DIFF(CURRENT_DATE(), DATE(u.created_at), DAY) AS account_age_days,
    -- Churn Probability
    COALESCE(p.churn_prob, 0.0) AS churn_probability_score,
    -- Predicted LTV
    COALESCE(p.predicted_ltv_val, 0.0) AS predicted_ltv,
    -- Customer Segment
    CASE
        WHEN p.predicted_ltv_val > 1000 THEN 'VIP'
        WHEN DATE_DIFF(CURRENT_DATE(), DATE(u.created_at), DAY) < 30 THEN 'New'
        WHEN p.churn_prob > 0.7 THEN 'AtRisk'
        ELSE 'Standard'
    END AS customer_segment,
    -- Resurrected Flag
    COALESCE(u.previous_status = 'CHURNED' AND u.status = 'ACTIVE', FALSE) AS is_resurrected,
    CURRENT_TIMESTAMP() AS feature_timestamp
FROM
    user_history AS u
LEFT JOIN
    churn_predictions AS p
    ON u.user_id = p.user_id AND p.rn = 1;
