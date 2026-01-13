-- Temporal Context Feature Pipeline
-- Target: company.features.v1.TemporalContext
-- Granularity: One row per event_id

SELECT
    event_id,
    -- Hour of Day
    EXTRACT(HOUR FROM event_timestamp) AS hour_of_day,
    -- Day of Week
    EXTRACT(DAYOFWEEK FROM event_timestamp) AS day_of_week, -- 1=Sunday in BQ, check proto def (1=Monday)
    -- Month
    EXTRACT(MONTH FROM event_timestamp) AS month_of_year,
    -- Is Holiday (Join with holiday calendar)
    COALESCE(h.is_holiday, FALSE) AS is_holiday,
    -- Is Weekend
    CASE
        WHEN EXTRACT(DAYOFWEEK FROM event_timestamp) IN (1, 7) THEN TRUE -- Sun, Sat
        ELSE FALSE
    END AS is_weekend,
    -- Epoch Seconds
    UNIX_SECONDS(event_timestamp) AS epoch_seconds,
    CURRENT_TIMESTAMP() AS feature_timestamp
FROM
    raw.events e
LEFT JOIN
    ref.calendar_holidays h ON DATE(e.event_timestamp) = h.calendar_date;
