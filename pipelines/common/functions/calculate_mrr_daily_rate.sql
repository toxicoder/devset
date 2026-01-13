CREATE TEMP FUNCTION calculate_mrr_daily_rate(
    amount_cents INT64, start_date DATE, end_date DATE
)
RETURNS FLOAT64 AS (
    -- Daily rate = total amount / duration in days (inclusive)
    -- Returns float, which can be summed up
    amount_cents / (date_diff(end_date, start_date, DAY) + 1)
);
