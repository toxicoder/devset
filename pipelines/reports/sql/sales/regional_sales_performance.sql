-- Regional Sales Performance
-- Source: company.sales.v1.Opportunity, company.sales.v1.Customer
-- Logic: Aggregates closed revenue by customer region.

SELECT
    c.billing_address.country AS billing_country,
    c.billing_address.state AS region,
    DATE_TRUNC(o.close_date, QUARTER) AS sales_quarter,
    COUNT(DISTINCT o.opportunity_id) AS deals_closed,
    SUM(o.amount_cents) / 100.0 AS total_bookings,
    AVG(o.amount_cents) / 100.0 AS avg_deal_size
FROM
    `company_sales_v1_opportunity` AS o
INNER JOIN
    `company_sales_v1_customer` AS c
    ON o.customer_id = c.customer_id
WHERE
    o.stage = 'CLOSED_WON'
GROUP BY
    billing_country,
    region,
    sales_quarter
ORDER BY
    total_bookings DESC;
