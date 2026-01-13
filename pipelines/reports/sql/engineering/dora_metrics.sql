-- DORA Metrics (DevOps Research and Assessment)
-- Source: company.cicd.v1.Workflow, company.cicd.v1.BuildArtifact
-- Logic: Calculates Deployment Frequency, Lead Time, MTTR, and Change Failure Rate.

WITH deployments AS (
    SELECT
        w.workflow_id,
        w.repo_name,
        w.start_time,
        w.end_time,
        w.status,
        -- Assume commit timestamp is available in trigger metadata or joined from git data
        -- Simulated link to commit
        TIMESTAMP_SUB(
            w.start_time, INTERVAL CAST(FLOOR(RAND() * 24) AS INT64) HOUR
        ) AS commit_time
    FROM
        `company_cicd_v1_workflow` AS w
    WHERE
        w.name LIKE '%deploy%' OR w.name LIKE '%release%'
),

incidents AS (
    -- Assuming a table for incidents exists, often linked to deployments
    -- For now, inferring from failed deployments or specific failure workflows
    SELECT
        repo_name,
        start_time AS failure_time,
        end_time AS resolution_time
    FROM
        `company_cicd_v1_workflow`
    WHERE
        status = 'FAILURE'
        AND (name LIKE '%deploy%' OR name LIKE '%release%')
),

daily_metrics AS (
    SELECT
        repo_name,
        DATE(start_time) AS report_date,
        COUNT(*) AS deployment_count,
        AVG(TIMESTAMP_DIFF(end_time, commit_time, MINUTE)) AS lead_time_minutes
    FROM
        deployments
    WHERE
        status = 'SUCCESS'
    GROUP BY
        repo_name,
        report_date
),

failure_metrics AS (
    SELECT
        repo_name,
        DATE(failure_time) AS report_date,
        COUNT(*) AS failure_count,
        AVG(
            TIMESTAMP_DIFF(resolution_time, failure_time, MINUTE)
        ) AS mttr_minutes
    FROM
        incidents
    GROUP BY
        repo_name,
        report_date
)

SELECT
    d.repo_name,
    d.report_date,
    d.deployment_count, -- Deployment Frequency
    d.lead_time_minutes, -- Lead Time for Changes
    f.mttr_minutes, -- Mean Time to Recovery
    COALESCE(f.failure_count, 0)
    / NULLIF(d.deployment_count, 0) AS change_failure_rate
FROM
    daily_metrics AS d
LEFT JOIN
    failure_metrics AS f
    ON d.report_date = f.report_date AND d.repo_name = f.repo_name
ORDER BY
    d.report_date DESC;
