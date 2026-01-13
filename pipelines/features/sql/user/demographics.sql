-- User Demographics Feature Pipeline
-- Target: company.features.v1.UserDemographics
-- Granularity: One row per user_id

WITH latest_user_profile AS (
    SELECT
        user_id,
        birth_date,
        gender_identity AS gender,
        country_code,
        language_pref AS language_code,
        city_name,
        updated_at,
        ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY updated_at DESC) as rn
    FROM
        raw.user_profiles
),

city_stats AS (
    SELECT
        city_name,
        country_code,
        CASE
            WHEN population > 1000000 THEN 'Urban'
            WHEN population > 100000 THEN 'Suburban'
            ELSE 'Rural'
        END AS urbanization_level
    FROM
        ref.geo_cities
)

SELECT
    u.user_id,
    -- Calculate Age Bucket
    CASE
        WHEN DATE_DIFF(CURRENT_DATE(), u.birth_date, YEAR) < 18 THEN 'Under 18'
        WHEN DATE_DIFF(CURRENT_DATE(), u.birth_date, YEAR) BETWEEN 18 AND 24 THEN '18-24'
        WHEN DATE_DIFF(CURRENT_DATE(), u.birth_date, YEAR) BETWEEN 25 AND 34 THEN '25-34'
        WHEN DATE_DIFF(CURRENT_DATE(), u.birth_date, YEAR) BETWEEN 35 AND 44 THEN '35-44'
        WHEN DATE_DIFF(CURRENT_DATE(), u.birth_date, YEAR) BETWEEN 45 AND 54 THEN '45-54'
        WHEN DATE_DIFF(CURRENT_DATE(), u.birth_date, YEAR) >= 55 THEN '55+'
        ELSE 'Unknown'
    END AS age_bucket,
    COALESCE(u.gender, 'Unknown') AS gender,
    COALESCE(u.country_code, 'XX') AS country_code,
    COALESCE(u.language_code, 'en') AS language_code,
    COALESCE(c.urbanization_level, 'Unknown') AS urbanization_level,
    CURRENT_TIMESTAMP() AS feature_timestamp
FROM
    latest_user_profile u
LEFT JOIN
    city_stats c ON u.city_name = c.city_name AND u.country_code = c.country_code
WHERE
    u.rn = 1;
