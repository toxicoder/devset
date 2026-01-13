CREATE TEMP FUNCTION calculate_customer_segment(
    predicted_ltv FLOAT64, created_at TIMESTAMP, churn_prob FLOAT64
)
RETURNS STRING AS (
    CASE
        WHEN predicted_ltv > 1000 THEN 'VIP'
        WHEN DATE_DIFF(CURRENT_DATE(), DATE(created_at), DAY) < 30 THEN 'New'
        WHEN churn_prob > 0.7 THEN 'AtRisk'
        ELSE 'Standard'
    END
);
