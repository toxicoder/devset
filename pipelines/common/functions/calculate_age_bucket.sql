CREATE TEMP FUNCTION calculate_age_bucket(birth_date DATE)
RETURNS STRING AS (
    CASE
        WHEN birth_date IS NULL THEN 'Unknown'
        WHEN date_diff(current_date(), birth_date, YEAR) < 18 THEN 'Under 18'
        WHEN
            date_diff(current_date(), birth_date, YEAR) BETWEEN 18 AND 24
            THEN '18-24'
        WHEN
            date_diff(current_date(), birth_date, YEAR) BETWEEN 25 AND 34
            THEN '25-34'
        WHEN
            date_diff(current_date(), birth_date, YEAR) BETWEEN 35 AND 44
            THEN '35-44'
        WHEN
            date_diff(current_date(), birth_date, YEAR) BETWEEN 45 AND 54
            THEN '45-54'
        WHEN date_diff(current_date(), birth_date, YEAR) >= 55 THEN '55+'
        ELSE 'Unknown'
    END
);
