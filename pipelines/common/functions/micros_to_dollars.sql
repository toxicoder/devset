CREATE TEMP FUNCTION micros_to_dollars(amount_micros FLOAT64)
RETURNS FLOAT64 AS (
    amount_micros / 1000000.0
);
