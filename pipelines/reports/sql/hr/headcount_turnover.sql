-- Headcount & Turnover
-- Source: company.hr.v1.Employee
-- Logic: Tracks active employees and attrition over time.

WITH monthly_snapshots AS (
    SELECT DATE_TRUNC(calendar_date, MONTH) AS snapshot_month
    FROM
        UNNEST(
            GENERATE_DATE_ARRAY(
                DATE('2020-01-01'), CURRENT_DATE(), INTERVAL 1 MONTH
            )
        ) AS calendar_date
),

employee_activity AS (
    SELECT
        e.employee_id,
        e.start_date,
        e.end_date,
        e.department
    FROM
        `company_hr_v1_employee` AS e
)

SELECT
    s.snapshot_month,
    ea.department,
    COUNT(DISTINCT CASE
        WHEN
            ea.start_date <= s.snapshot_month
            AND (ea.end_date IS NULL OR ea.end_date > s.snapshot_month)
            THEN ea.employee_id
    END) AS beginning_headcount,
    COUNT(DISTINCT CASE
        WHEN DATE_TRUNC(ea.start_date, MONTH) = s.snapshot_month
            THEN ea.employee_id
    END) AS new_hires,
    COUNT(DISTINCT CASE
        WHEN DATE_TRUNC(ea.end_date, MONTH) = s.snapshot_month
            THEN ea.employee_id
    END) AS departures,
    -- Turnover Rate = Departures / Avg Headcount
    SAFE_DIVIDE(
        COUNT(
            DISTINCT CASE
                WHEN DATE_TRUNC(ea.end_date, MONTH) = s.snapshot_month
                    THEN ea.employee_id
            END
        ),
        (
            COUNT(
                DISTINCT CASE
                    WHEN
                        ea.start_date <= s.snapshot_month
                        AND (
                            ea.end_date IS NULL
                            OR ea.end_date > s.snapshot_month
                        )
                        THEN ea.employee_id
                END
            ) + COUNT(
                DISTINCT CASE
                    WHEN
                        ea.start_date <= DATE_ADD(
                            s.snapshot_month, INTERVAL 1 MONTH
                        )
                        AND (
                            ea.end_date IS NULL
                            OR ea.end_date > DATE_ADD(
                                s.snapshot_month, INTERVAL 1 MONTH
                            )
                        )
                        THEN ea.employee_id
                END
            )
        ) / 2
    ) AS turnover_rate
FROM
    monthly_snapshots AS s
CROSS JOIN
    employee_activity AS ea
GROUP BY
    s.snapshot_month,
    ea.department
ORDER BY
    s.snapshot_month DESC,
    ea.department ASC;
