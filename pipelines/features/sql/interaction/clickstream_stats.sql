-- Clickstream Stats Feature Pipeline
-- Target: company.features.v1.ClickstreamStats
-- Granularity: One row per interaction_id (or item context)

WITH item_views AS (
    SELECT
        item_id,
        context_id,
        COUNT(*) as view_count,
        COUNT(CASE WHEN event_type = 'CLICK' THEN 1 END) as click_count,
        AVG(dwell_time_ms) / 1000.0 as avg_dwell_time_seconds,
        COUNT(CASE WHEN is_bounce = TRUE THEN 1 END) as bounce_count
    FROM
        derived.item_interactions
    GROUP BY
        item_id, context_id
)

SELECT
    CONCAT(item_id, '_', context_id) AS interaction_id,
    -- CTR
    SAFE_DIVIDE(click_count, view_count) AS ctr,
    view_count,
    click_count,
    avg_dwell_time_seconds,
    -- Bounce Rate
    SAFE_DIVIDE(bounce_count, view_count) AS bounce_rate,
    -- Referrer (Mode)
    'Search' AS referrer_source, -- Placeholder for mode calculation
    CURRENT_TIMESTAMP() AS feature_timestamp
FROM
    item_views;
