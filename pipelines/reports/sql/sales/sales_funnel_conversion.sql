-- Sales Funnel Conversion Analysis
-- Source: company.sales.v1.Lead, company.sales.v1.Opportunity
-- Logic: Tracks conversion rates between funnel stages.

WITH funnel_stages AS (
    SELECT
        DATE_TRUNC(create_time, MONTH) AS cohort_month,
        COUNT(DISTINCT lead_id) AS total_leads,
        COUNT(
            DISTINCT CASE WHEN status = 'QUALIFIED' THEN lead_id END
        ) AS qualified_leads,
        COUNT(
            DISTINCT CASE
                WHEN converted_opportunity_id IS NOT NULL THEN lead_id
            END
        ) AS opportunities_created
    FROM
        `company_sales_v1_lead`
    GROUP BY
        cohort_month
),

opportunity_outcomes AS (
    SELECT
        DATE_TRUNC(create_time, MONTH) AS cohort_month,
        COUNT(DISTINCT opportunity_id) AS total_opportunities,
        COUNT(
            DISTINCT CASE WHEN stage = 'CLOSED_WON' THEN opportunity_id END
        ) AS closed_won,
        COUNT(
            DISTINCT CASE WHEN stage = 'CLOSED_LOST' THEN opportunity_id END
        ) AS closed_lost
    FROM
        `company_sales_v1_opportunity`
    GROUP BY
        cohort_month
)

SELECT
    f.cohort_month,
    f.total_leads,
    f.qualified_leads,
    f.opportunities_created,
    o.closed_won,
    SAFE_DIVIDE(
        f.qualified_leads, f.total_leads
    ) AS lead_qualification_rate,
    SAFE_DIVIDE(
        f.opportunities_created, f.qualified_leads
    ) AS opp_creation_rate,
    SAFE_DIVIDE(o.closed_won, o.total_opportunities) AS win_rate
FROM
    funnel_stages AS f
LEFT JOIN
    opportunity_outcomes AS o
    ON f.cohort_month = o.cohort_month
ORDER BY
    f.cohort_month DESC;
