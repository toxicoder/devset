-- Customer Acquisition Cost (CAC)
-- Source: company.marketing.v1.Campaign, company.sales.v1.Opportunity
-- Logic: Total Marketing Spend / New Customers Acquired

WITH campaign_spend AS (
    SELECT
        channel,
        -- e.g., 'Google Ads', 'LinkedIn', 'Organic'
        DATE_TRUNC(start_time, MONTH) AS month,
        SUM(cost_cents) / 100.0 AS total_spend
    FROM
        `company_marketing_v1_campaign`
    GROUP BY
        month,
        channel
),

new_customers AS (
    SELECT
        lead_source AS channel,
        DATE_TRUNC(close_date, MONTH) AS month,
        COUNT(DISTINCT customer_id) AS new_customers_count
    FROM
        `company_sales_v1_opportunity`
    WHERE
        stage = 'CLOSED_WON'
        AND type = 'NEW_BUSINESS'
    GROUP BY
        month,
        channel
)

SELECT
    COALESCE(s.month, c.month) AS report_month,
    COALESCE(s.channel, c.channel) AS acquisition_channel,
    COALESCE(c.new_customers_count, 0) AS customers_acquired,
    COALESCE(s.total_spend, 0) AS marketing_spend,
    CASE
        WHEN c.new_customers_count > 0
            THEN s.total_spend / c.new_customers_count
    END AS cac
FROM
    campaign_spend AS s
FULL OUTER JOIN
    new_customers AS c
    ON s.month = c.month AND s.channel = c.channel
ORDER BY
    report_month DESC,
    marketing_spend DESC;
