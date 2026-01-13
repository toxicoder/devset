-- Feature Adoption Rate
-- Source: company.features.v1.UserEngagement
-- Logic: Tracks the percentage of active users who interact with specific features.

WITH active_users AS (
    SELECT
        DATE_TRUNC(event_timestamp, DAY) AS report_date,
        COUNT(DISTINCT user_id) AS total_active_users
    FROM
        `company_features_v1_user_engagement`
    GROUP BY
        report_date
),

feature_usage AS (
    SELECT
        feature_name,
        DATE_TRUNC(event_timestamp, DAY) AS report_date,
        COUNT(DISTINCT user_id) AS feature_users
    FROM
        `company_features_v1_user_engagement`
    WHERE
        feature_name IS NOT NULL
    GROUP BY
        feature_name,
        report_date
)

SELECT
    fu.report_date,
    fu.feature_name,
    fu.feature_users,
    au.total_active_users,
    SAFE_DIVIDE(fu.feature_users, au.total_active_users) AS adoption_rate
FROM
    feature_usage AS fu
JOIN
    active_users AS au
    ON fu.report_date = au.report_date
ORDER BY
    fu.report_date DESC,
    adoption_rate DESC;
