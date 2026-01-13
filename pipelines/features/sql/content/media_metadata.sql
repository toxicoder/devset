-- Media Metadata Feature Pipeline
-- Target: company.features.v1.MediaMetadata
-- Granularity: One row per content_id

SELECT
    content_id,
    -- Visual Embedding
    visual_embedding_vector AS visual_embedding,
    -- Dimensions
    width_px AS width,
    height_px AS height,
    -- Duration
    duration_sec AS duration_seconds,
    -- Format
    mime_type,
    -- Color
    dominant_color_hex,
    -- NSFW Flag
    is_nsfw_detected AS is_nsfw,
    CURRENT_TIMESTAMP() AS feature_timestamp
FROM
    raw.media_metadata;
