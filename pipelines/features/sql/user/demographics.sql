CREATE TEMP FUNCTION calculate_age_bucket(birth_date DATE)
RETURNS STRING AS (
    CASE
        WHEN birth_date IS NULL THEN 'Unknown'
        WHEN date_diff(current_date(), birth_date, YEAR) < 18 THEN 'Under 18'
        WHEN
            date_diff(current_date(), birth_date, YEAR) BETWEEN 18 AND 24
            THEN '18-24'
        WHEN
            date_diff(current_date(), birth_date, YEAR) BETWEEN 25 AND 34
            THEN '25-34'
        WHEN
            date_diff(current_date(), birth_date, YEAR) BETWEEN 35 AND 44
            THEN '35-44'
        WHEN
            date_diff(current_date(), birth_date, YEAR) BETWEEN 45 AND 54
            THEN '45-54'
        WHEN date_diff(current_date(), birth_date, YEAR) >= 55 THEN '55+'
        ELSE 'Unknown'
    END
);

CREATE TEMP FUNCTION calculate_urbanization_level(population INT64)
RETURNS STRING AS (
    CASE
        WHEN population > 1000000 THEN 'Urban'
        WHEN population > 100000 THEN 'Suburban'
        ELSE 'Rural'
    END
);

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
        row_number() OVER (PARTITION BY user_id ORDER BY updated_at DESC) AS rn
    FROM
        raw.user_profiles
),

city_stats AS (
    SELECT
        city_name,
        country_code,
        calculate_urbanization_level(population) AS urbanization_level
    FROM
        ref.geo_cities
)

SELECT
    u.user_id,
    -- Calculate Age Bucket
    calculate_age_bucket(u.birth_date) AS age_bucket,
    coalesce(u.gender, 'Unknown') AS gender,
    coalesce(u.country_code, 'XX') AS country_code,
    coalesce(u.language_code, 'en') AS language_code,
    coalesce(c.urbanization_level, 'Unknown') AS urbanization_level,
    current_timestamp() AS feature_timestamp
FROM
    latest_user_profile AS u
LEFT JOIN
    city_stats AS c
    ON u.city_name = c.city_name AND u.country_code = c.country_code
WHERE
    u.rn = 1;
