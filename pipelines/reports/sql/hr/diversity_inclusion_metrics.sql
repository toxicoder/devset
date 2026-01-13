-- Diversity, Equity, & Inclusion (DEI) Metrics
-- Source: company.hr.v1.Employee (fields assumed from typical HR schemas)
-- Logic: Aggregates demographics to track representation.

SELECT
    department,
    DATE_TRUNC(CURRENT_DATE(), QUARTER) AS report_quarter,
    -- Gender Representation
    COUNT(CASE WHEN gender = 'FEMALE' THEN 1 END) AS female_count,
    COUNT(CASE WHEN gender = 'MALE' THEN 1 END) AS male_count,
    COUNT(
        CASE WHEN gender NOT IN ('FEMALE', 'MALE') THEN 1 END
    ) AS other_gender_count,

    -- Ethnicity Representation (Bucketed)
    COUNT(
        CASE WHEN ethnicity = 'UNDERREPRESENTED_MINORITY' THEN 1 END
    ) AS urm_count,
    COUNT(
        CASE WHEN ethnicity != 'UNDERREPRESENTED_MINORITY' THEN 1 END
    ) AS non_urm_count,

    -- Leadership Representation (Directors and above)
    COUNT(
        CASE WHEN job_level >= 6 AND gender = 'FEMALE' THEN 1 END
    ) AS female_leadership,
    COUNT(
        CASE
            WHEN job_level >= 6 AND ethnicity = 'UNDERREPRESENTED_MINORITY'
                THEN 1
        END
    ) AS urm_leadership,

    COUNT(*) AS total_headcount
FROM
    `company_hr_v1_employee`
WHERE
    employment_status = 'ACTIVE'
GROUP BY
    department,
    report_quarter
ORDER BY
    department;
