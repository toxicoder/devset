-- User Engagement Feature Pipeline
-- Target: company.features.v1.UserEngagement
-- Granularity: One row per user_id

WITH session_stats AS (
    SELECT
        user_id,
        session_id,
        session_start_ts,
        TIMESTAMP_DIFF(session_end_ts, session_start_ts, SECOND)
            AS session_duration_seconds
    FROM
        derived.sessions
    WHERE
        session_start_ts >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
),

login_activity AS (
    SELECT
        user_id,
        MAX(login_ts) AS last_login_ts
    FROM
        raw.auth_logs
    GROUP BY
        user_id
)

SELECT
    u.user_id,
    -- Sessions in last 7 days
    COUNT(
        CASE
            WHEN
                s.session_start_ts
                >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
                THEN 1
        END
    ) AS sessions_last_7d,
    -- Sessions in last 30 days
    COUNT(s.session_id) AS sessions_last_30d,
    -- Avg session length
    COALESCE(AVG(s.session_duration_seconds), 0) AS avg_session_length_seconds,
    -- Days since last login
    DATE_DIFF(CURRENT_DATE(), DATE(l.last_login_ts), DAY)
        AS days_since_last_login,
    -- Frequency Segment
    CASE
        WHEN
            COUNT(
                CASE
                    WHEN
                        s.session_start_ts
                        >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
                        THEN 1
                END
            )
            >= 5
            THEN 'Daily'
        WHEN
            COUNT(
                CASE
                    WHEN
                        s.session_start_ts
                        >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
                        THEN 1
                END
            )
            >= 1
            THEN 'Weekly'
        ELSE 'Sporadic'
    END AS frequency_segment,
    CURRENT_TIMESTAMP() AS feature_timestamp
FROM
    (SELECT DISTINCT user_id FROM raw.users) AS u
LEFT JOIN
    session_stats AS s
    ON u.user_id = s.user_id
LEFT JOIN
    login_activity AS l
    ON u.user_id = l.user_id
GROUP BY
    u.user_id, l.last_login_ts;
