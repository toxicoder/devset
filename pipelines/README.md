# Feature Engineering Pipelines

This directory contains SQL pipelines used to generate features defined in the `company.features.v1` Protocol Buffers.

## Structure

The directory structure mirrors the Protocol Buffer package structure:

*   `user/`: Features related to `UserFeatures` (Demographics, Engagement, Lifecycle).
*   `commerce/`: Features related to `CommerceFeatures` (Purchase Stats, Payment Behavior, Cart Metrics).
*   `content/`: Features related to `ContentFeatures` (Text Analysis, Media Metadata).
*   `context/`: Features related to `ContextFeatures` (Device, Geo, Temporal).
*   `interaction/`: Features related to `InteractionFeatures` (Clickstream, Social Graph).

## Usage

These SQL scripts are designed to be run against a data warehouse (e.g., BigQuery, Snowflake, Spark SQL) to produce tables that can be exported or served as features.

Each script typically reads from raw event tables or intermediate derived tables and produces a final feature table keyed by the entity ID (e.g., `user_id`, `content_id`).
