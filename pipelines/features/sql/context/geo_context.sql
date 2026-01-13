-- Geo Context Feature Pipeline
-- Target: company.features.v1.GeoContext
-- Granularity: One row per event_id

SELECT
    e.event_id,
    -- IP Derived Location
    g.country_iso_code AS ip_country,
    g.city_name AS ip_city,
    -- Coarse Coordinates
    g.latitude,
    g.longitude,
    -- Timezone
    g.time_zone AS timezone,
    -- Accuracy
    g.accuracy_radius AS accuracy_meters,
    CURRENT_TIMESTAMP() AS feature_timestamp
FROM
    raw.events e
LEFT JOIN
    ref.ip_geo_mapping g ON e.ip_address = g.ip_address_block;
