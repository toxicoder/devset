-- Campaign ROI & Attribution
-- Source: company.marketing.v1.Campaign, company.sales.v1.Opportunity
-- Logic: Attributes revenue to campaigns to calculate ROI.

SELECT
    c.campaign_id,
    c.name AS campaign_name,
    c.channel,
    c.cost_cents / 100.0 AS campaign_cost,
    COUNT(DISTINCT o.opportunity_id) AS opportunities_generated,
    SUM(
        CASE WHEN o.stage = 'CLOSED_WON' THEN o.amount_cents ELSE 0 END
    ) / 100.0 AS revenue_generated,
    (
        SUM(
            CASE WHEN o.stage = 'CLOSED_WON' THEN o.amount_cents ELSE 0 END
        ) - c.cost_cents
    ) / 100.0 AS net_profit,
    CASE
        WHEN c.cost_cents > 0
            THEN (
                SUM(
                    CASE
                        WHEN o.stage = 'CLOSED_WON' THEN o.amount_cents ELSE 0
                    END
                ) - c.cost_cents
            ) / c.cost_cents
        ELSE 0
    END AS roi_percentage
FROM
    `company_marketing_v1_campaign` AS c
LEFT JOIN
    `company_sales_v1_lead` AS l
    ON c.campaign_id = l.campaign_id
LEFT JOIN
    `company_sales_v1_opportunity` AS o
    ON l.converted_opportunity_id = o.opportunity_id
GROUP BY
    c.campaign_id,
    c.name,
    c.channel,
    c.cost_cents
ORDER BY
    revenue_generated DESC;
