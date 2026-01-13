CREATE TEMP FUNCTION cents_to_dollars(amount_cents FLOAT64)
RETURNS FLOAT64 AS (
    amount_cents / 100.0
);

-- Vendor Spend Analysis
-- Source: company.finance.v1.ExpenseReport
-- Logic: Aggregates spend by vendor and category to identify top cost centers.

SELECT
    vendor_name,
    category, -- e.g., 'Software', 'Travel', 'Meals'
    DATE_TRUNC(date, MONTH) AS spend_month,
    COUNT(*) AS transaction_count,
    cents_to_dollars(SUM(amount_cents)) AS total_spend,
    cents_to_dollars(AVG(amount_cents)) AS avg_transaction_value
FROM
    `company_finance_v1_expense_report`
WHERE
    date >= DATE_SUB(CURRENT_DATE(), INTERVAL 12 MONTH)
    AND status = 'APPROVED'
GROUP BY
    vendor_name,
    category,
    spend_month
ORDER BY
    total_spend DESC;
