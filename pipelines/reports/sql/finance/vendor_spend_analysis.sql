-- Vendor Spend Analysis
-- Source: company.finance.v1.ExpenseReport
-- Logic: Aggregates spend by vendor and category to identify top cost centers.

SELECT
    vendor_name,
    category, -- e.g., 'Software', 'Travel', 'Meals'
    DATE_TRUNC(date, MONTH) AS spend_month,
    COUNT(*) AS transaction_count,
    SUM(amount_cents) / 100.0 AS total_spend,
    AVG(amount_cents) / 100.0 AS avg_transaction_value
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
