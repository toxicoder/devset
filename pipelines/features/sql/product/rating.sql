-- Product Rating Feature Pipeline
-- Target: company.features.v1.ProductRating
-- Granularity: One row per product_id

WITH reviews AS (
    SELECT
        product_id,
        rating,
        sentiment_score, -- Pre-calculated NLP score
        created_at
    FROM
        raw.product_reviews
)

SELECT
    product_id,
    AVG(rating) AS average_rating,
    COUNT(*) AS review_count,
    AVG(sentiment_score) AS sentiment_score,
    COUNTIF(rating = 5) AS five_star_count,
    CURRENT_TIMESTAMP() AS feature_timestamp
FROM
    reviews
GROUP BY
    product_id;
