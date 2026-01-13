CREATE TEMP FUNCTION cents_to_dollars(amount_cents FLOAT64)
RETURNS FLOAT64 AS (
    amount_cents / 100.0
);
