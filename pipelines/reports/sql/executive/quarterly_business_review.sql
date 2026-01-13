-- Quarterly Business Review (QBR) Aggregation
-- Source: Aggregates metrics from Finance, Sales, and Product.

WITH finance AS (
    SELECT
        DATE_TRUNC(issue_date, QUARTER) AS fiscal_quarter,
        SUM(total_amount_cents) / 100.0 AS revenue
    FROM
        `company_finance_v1_invoice`
    WHERE
        status = 'PAID'
    GROUP BY
        fiscal_quarter
),

sales AS (
    SELECT
        DATE_TRUNC(close_date, QUARTER) AS fiscal_quarter,
        COUNT(DISTINCT opportunity_id) AS deals_closed,
        SUM(amount_cents) / 100.0 AS bookings
    FROM
        `company_sales_v1_opportunity`
    WHERE
        stage = 'CLOSED_WON'
    GROUP BY
        fiscal_quarter
),

product AS (
    SELECT
        DATE_TRUNC(event_timestamp, QUARTER) AS fiscal_quarter,
        COUNT(DISTINCT user_id) AS active_users
    FROM
        `company_features_v1_user_engagement`
    GROUP BY
        fiscal_quarter
)

SELECT
    COALESCE(f.fiscal_quarter, s.fiscal_quarter, p.fiscal_quarter)
        AS report_quarter,
    COALESCE(f.revenue, 0) AS recognized_revenue,
    COALESCE(s.bookings, 0) AS total_bookings,
    COALESCE(s.deals_closed, 0) AS new_logos,
    COALESCE(p.active_users, 0) AS quarterly_active_users
FROM
    finance AS f
FULL OUTER JOIN
    sales AS s
    ON f.fiscal_quarter = s.fiscal_quarter
FULL OUTER JOIN
    product AS p
    ON f.fiscal_quarter = p.fiscal_quarter
ORDER BY
    report_quarter DESC;
