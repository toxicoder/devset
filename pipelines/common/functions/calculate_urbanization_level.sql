CREATE TEMP FUNCTION calculate_urbanization_level(population INT64)
RETURNS STRING AS (
    CASE
        WHEN population > 1000000 THEN 'Urban'
        WHEN population > 100000 THEN 'Suburban'
        ELSE 'Rural'
    END
);
