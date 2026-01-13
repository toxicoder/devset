CREATE TEMP FUNCTION calculate_frequency_segment(sessions_last_7d INT64)
RETURNS STRING AS (
    CASE
        WHEN sessions_last_7d >= 5 THEN 'Daily'
        WHEN sessions_last_7d >= 1 THEN 'Weekly'
        ELSE 'Sporadic'
    END
);
