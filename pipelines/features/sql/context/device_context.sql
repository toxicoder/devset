-- Device Context Feature Pipeline
-- Target: company.features.v1.DeviceContext
-- Granularity: One row per event_id

SELECT
    event_id,
    -- OS Family
    CASE
        WHEN user_agent LIKE '%iPhone%' OR user_agent LIKE '%iPad%' THEN 'iOS'
        WHEN user_agent LIKE '%Android%' THEN 'Android'
        WHEN user_agent LIKE '%Windows%' THEN 'Windows'
        ELSE 'Other'
    END AS os_family,
    -- OS Version (simplified regex extraction)
    REGEXP_EXTRACT(user_agent, r'OS ([\d_]+)') AS os_version,
    -- Browser Name
    browser_family AS browser_name,
    -- Device Model
    device_model,
    -- App Version
    client_app_version AS app_version,
    -- Connection Type
    connection_type, -- WiFi, 4G, etc.
    -- Battery Level
    battery_level,
    CURRENT_TIMESTAMP() AS feature_timestamp
FROM
    raw.mobile_events;
