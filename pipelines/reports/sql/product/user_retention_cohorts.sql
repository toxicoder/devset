-- User Retention Cohorts
-- Source: company.features.v1.UserEngagement
-- Logic: Calculates weekly retention rates for user cohorts.

WITH user_activity AS (
    SELECT
        user_id,
        DATE_TRUNC(event_timestamp, WEEK) AS activity_week
    FROM
        `company_features_v1_user_engagement`
    GROUP BY
        1, 2
),

cohorts AS (
    SELECT
        user_id,
        MIN(activity_week) AS cohort_week
    FROM
        user_activity
    GROUP BY
        1
),

retention AS (
    SELECT
        c.cohort_week,
        DATE_DIFF(ua.activity_week, c.cohort_week, WEEK) AS weeks_since_join,
        COUNT(DISTINCT c.user_id) AS active_users
    FROM
        cohorts AS c
    INNER JOIN
        user_activity AS ua
        ON c.user_id = ua.user_id
    GROUP BY
        1, 2
)

SELECT
    cohort_week,
    weeks_since_join,
    active_users,
    active_users
    / FIRST_VALUE(active_users)
        OVER (PARTITION BY cohort_week ORDER BY weeks_since_join)
        AS retention_rate
FROM
    retention
ORDER BY
    1 DESC, 2;
