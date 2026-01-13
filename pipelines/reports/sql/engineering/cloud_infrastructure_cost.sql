-- Cloud Infrastructure Cost Allocation
-- Source: company.infrastructure.v1.BillingRecord (inferred)
-- Logic: Attributes cloud spend to teams based on tags.

SELECT
    provider, -- AWS, GCP, Azure
    service, -- EC2, BigQuery, S3
    DATE_TRUNC(usage_date, MONTH) AS billing_month,
    -- Extract 'Team' or 'Service' tag from labels
    (
        SELECT value FROM UNNEST(labels)
        WHERE key = 'Team'
    ) AS team_name,
    SUM(cost_micros) / 1000000.0 AS total_cost,
    SUM(credits_micros) / 1000000.0 AS total_credits,
    (
        SUM(cost_micros) - SUM(credits_micros)
    ) / 1000000.0 AS net_cost
FROM
    `company_infrastructure_v1_billing_record`
WHERE
    usage_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 12 MONTH)
GROUP BY
    provider,
    service,
    billing_month,
    team_name
ORDER BY
    net_cost DESC;
