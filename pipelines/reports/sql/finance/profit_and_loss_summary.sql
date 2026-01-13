-- Profit & Loss (P&L) Summary
-- Source: company.finance.v1.Budget (inferred for planned) and Actuals.

WITH revenue AS (
    SELECT
        DATE_TRUNC(issue_date, MONTH) AS month,
        SUM(total_amount_cents) / 100.0 AS total_revenue
    FROM
        `company_finance_v1_invoice`
    WHERE
        status = 'PAID'
    GROUP BY
        month
),

expenses AS (
    SELECT
        category,
        DATE_TRUNC(date, MONTH) AS month,
        SUM(amount_cents) / 100.0 AS total_expense
    FROM
        `company_finance_v1_expense_report`
    WHERE
        status = 'APPROVED'
    GROUP BY
        category,
        month
),

aggregated_expenses AS (
    SELECT
        month,
        SUM(total_expense) AS total_opex
    FROM
        expenses
    GROUP BY
        month
)

SELECT
    COALESCE(r.month, e.month) AS report_month,
    COALESCE(r.total_revenue, 0) AS revenue,
    COALESCE(e.total_opex, 0) AS opex,
    COALESCE(r.total_revenue, 0) - COALESCE(e.total_opex, 0) AS net_income,
    CASE
        WHEN COALESCE(r.total_revenue, 0) > 0
            THEN (
                COALESCE(r.total_revenue, 0) - COALESCE(e.total_opex, 0)
            ) / r.total_revenue
        ELSE 0
    END AS net_income_margin
FROM
    revenue AS r
FULL OUTER JOIN
    aggregated_expenses AS e
    ON r.month = e.month
ORDER BY
    report_month DESC;
