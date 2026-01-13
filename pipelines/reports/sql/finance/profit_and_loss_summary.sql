CREATE TEMP FUNCTION cents_to_dollars(amount_cents FLOAT64)
RETURNS FLOAT64 AS (
    amount_cents / 100.0
);

-- Profit & Loss (P&L) Summary
-- Source: company.finance.v1.Budget (inferred for planned) and Actuals.

WITH revenue AS (
    SELECT
        date_trunc(issue_date, MONTH) AS month,
        cents_to_dollars(sum(total_amount_cents)) AS total_revenue
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
        date_trunc(date, MONTH) AS month,
        cents_to_dollars(sum(amount_cents)) AS total_expense
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
        sum(total_expense) AS total_opex
    FROM
        expenses
    GROUP BY
        month
)

SELECT
    coalesce(r.month, e.month) AS report_month,
    coalesce(r.total_revenue, 0) AS revenue,
    coalesce(e.total_opex, 0) AS opex,
    coalesce(r.total_revenue, 0) - coalesce(e.total_opex, 0) AS net_income,
    CASE
        WHEN coalesce(r.total_revenue, 0) > 0
            THEN (
                coalesce(r.total_revenue, 0) - coalesce(e.total_opex, 0)
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
