CREATE TEMP FUNCTION calculate_mrr_daily_rate(
    amount_cents INT64, start_date DATE, end_date DATE
)
RETURNS FLOAT64 AS (
    -- Daily rate = total amount / duration in days (inclusive)
    -- Returns float, which can be summed up
    amount_cents / (date_diff(end_date, start_date, DAY) + 1)
);

CREATE TEMP FUNCTION cents_to_dollars(amount_cents FLOAT64)
RETURNS FLOAT64 AS (
    amount_cents / 100.0
);

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
    SELECT date_trunc(DAY, MONTH) AS snapshot_month
    FROM
        unnest(
            generate_date_array(
                date('2020-01-01'), current_date(), INTERVAL 1 MONTH
            )
        ) AS day
),

active_subscriptions AS (
    SELECT
        ms.snapshot_month,
        ii.customer_id,
        calculate_mrr_daily_rate(
            ii.amount_cents, ii.period_start_date, ii.period_end_date
        ) AS daily_rate_cents
    FROM
        monthly_snapshots AS ms
    INNER JOIN
        invoice_items AS ii
        ON
            -- Check if subscription was active on the first day of the snapshot month
            -- or generally active during that month.
            -- Using "active at end of month" logic is standard for MRR.
            ii.period_start_date <= last_day(ms.snapshot_month)
            AND ii.period_end_date >= last_day(ms.snapshot_month)
            AND ii.subscription_type IN ('ANNUAL', 'MONTHLY')
)

SELECT
    format_date('%Y-%m', snapshot_month) AS month,
    count(DISTINCT customer_id) AS active_customers,
    -- MRR = Sum of Daily Rate of active subs * 30.44
    cents_to_dollars(sum(daily_rate_cents)) * 30.44 AS mrr_estimated,
    -- ARR = MRR * 12
    (cents_to_dollars(sum(daily_rate_cents)) * 30.44) * 12 AS arr_estimated
FROM
    active_subscriptions
GROUP BY
    month
ORDER BY
    month DESC;
