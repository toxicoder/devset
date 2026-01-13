-- Monthly Recurring Revenue (MRR) & Annual Recurring Revenue (ARR) Calculation
-- Source: company.finance.v1.Invoice
-- Logic: Sums up recognized revenue for subscription items active in the current month.

WITH invoice_items AS (
    SELECT
        invoice_id,
        customer_id,
        item_description,
        amount_cents,
        period_start_date,
        period_end_date,
        -- Assume 'SUBSCRIPTION' type based on description or separate type field
        CASE
            WHEN item_description LIKE '%Annual%' THEN 'ANNUAL'
            WHEN item_description LIKE '%Monthly%' THEN 'MONTHLY'
            ELSE 'ONE_OFF'
        END AS subscription_type
    FROM
        `company_finance_v1_invoice_item`
),

monthly_snapshots AS (
    SELECT DATE_TRUNC(DAY, MONTH) AS snapshot_month
    FROM
        UNNEST(
            GENERATE_DATE_ARRAY(
                DATE('2020-01-01'), CURRENT_DATE(), INTERVAL 1 MONTH
            )
        ) AS day
),

active_subscriptions AS (
    SELECT
        ms.snapshot_month,
        ii.customer_id,
        ii.amount_cents
        / (
            DATE_DIFF(ii.period_end_date, ii.period_start_date, DAY) + 1
        ) AS daily_rate_cents
    FROM
        monthly_snapshots AS ms
    INNER JOIN
        invoice_items AS ii
        ON
            -- Check if subscription was active on the first day of the snapshot month
            -- or generally active during that month.
            -- Using "active at end of month" logic is standard for MRR.
            ii.period_start_date <= LAST_DAY(ms.snapshot_month)
            AND ii.period_end_date >= LAST_DAY(ms.snapshot_month)
            AND ii.subscription_type IN ('ANNUAL', 'MONTHLY')
)

SELECT
    FORMAT_DATE('%Y-%m', snapshot_month) AS month,
    COUNT(DISTINCT customer_id) AS active_customers,
    -- MRR = Sum of Daily Rate of active subs * 30.44
    SUM(daily_rate_cents) / 100.0 * 30.44 AS mrr_estimated,
    -- ARR = MRR * 12
    (SUM(daily_rate_cents) / 100.0 * 30.44) * 12 AS arr_estimated
FROM
    active_subscriptions
GROUP BY
    month
ORDER BY
    month DESC;
