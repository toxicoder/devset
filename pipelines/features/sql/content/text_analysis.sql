-- Text Analysis Feature Pipeline
-- Target: company.features.v1.TextAnalysis
-- Granularity: One row per content_id

-- Note: Much of this would likely come from an ML inference pipeline (e.g. BERT/LLM),
-- stored in a table, rather than pure SQL calculation.

SELECT
    content_id,
    -- Embedding (Assumed to be stored as array<float> or binary)
    embedding_vector AS embedding,
    -- Sentiment Score
    sentiment_score, -- -1.0 to 1.0
    -- Toxicity Score
    toxicity_probability AS toxicity_score,
    -- Language
    detected_language AS language,
    language_confidence,
    -- Topics (Array)
    extracted_topics AS topics,
    -- Readability
    flesch_kincaid_score AS readability_score,
    CURRENT_TIMESTAMP() AS feature_timestamp
FROM
    derived.content_ml_inference_results;
