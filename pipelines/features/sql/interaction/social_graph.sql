-- Social Graph Feature Pipeline
-- Target: company.features.v1.SocialGraph
-- Granularity: One row per interaction_id (user_id)

WITH connections AS (
    SELECT
        user_id,
        COUNT(friend_id) as friend_count
    FROM
        raw.friendships
    GROUP BY
        user_id
),

followers AS (
    SELECT
        user_id,
        COUNT(follower_id) as follower_count
    FROM
        raw.user_followers
    GROUP BY
        user_id
),

following AS (
    SELECT
        follower_id as user_id,
        COUNT(user_id) as following_count
    FROM
        raw.user_followers
    GROUP BY
        follower_id
),

graph_metrics AS (
    -- Assumes pre-computed graph metrics
    SELECT
        user_id,
        clustering_coeff,
        pagerank_score,
        embedding_vector
    FROM
        derived.graph_analytics
)

SELECT
    u.user_id AS interaction_id,
    COALESCE(c.friend_count, 0) AS friend_count,
    COALESCE(f.follower_count, 0) AS follower_count,
    COALESCE(fg.following_count, 0) AS following_count,
    gm.embedding_vector AS graph_embedding,
    COALESCE(gm.clustering_coeff, 0.0) AS clustering_coefficient,
    COALESCE(gm.pagerank_score, 0.0) AS centrality_score,
    CURRENT_TIMESTAMP() AS feature_timestamp
FROM
    (SELECT DISTINCT user_id FROM raw.users) u
LEFT JOIN
    connections c ON u.user_id = c.user_id
LEFT JOIN
    followers f ON u.user_id = f.user_id
LEFT JOIN
    following fg ON u.user_id = fg.user_id
LEFT JOIN
    graph_metrics gm ON u.user_id = gm.user_id;
