---
layout: page
title: Performance Review Policy
permalink: /policies/performance_review_policy/
---

## Nexus Evaluation Framework (NEF)

## 1. Introduction & Philosophy

The Nexus Evaluation Framework (NEF) is a **mostly automated** performance review
system designed to eliminate subjectivity through data-driven precision. By
integrating real-time data streams, AI-driven bias mitigation, and **predefined
metrics**, NEF operates on a continuous "nexus" model where individual, team,
and company performance intersect in a dynamic, verifiable ecosystem. Human
intervention is minimized and reserved primarily for coaching and exception
handling, ensuring that 90%+ of the evaluation is derived directly from
verifiable code and data.

## 2. Scope

This policy applies to all employees across the organization. The specific
metrics and weights vary by role but are standardized within each Job Role Code
(e.g., `SWEN1002`).

## 3. Core Principles

* **Logic**: Evaluations are algorithmic, rooted in verifiable data from the
  Company Feature Store (`company.features.v1`).
* **Effectiveness**: Automated interventions boost productivity in real-time.
* **Fairness**: Demographic-blind scoring and automated equity checks prevent
  discrimination.
* **Clarity**: All metrics are predefined in the codebase; no "surprise"
  criteria.
* **Consistency**: Standardized SQL pipelines enforce uniform calculation globally.

## 4. Roles & Responsibilities

* **Employees**: Select relevant metrics from the Predefined Metric Library and
  monitor their automated dashboard.
* **Managers**: Review automated scores, handle exceptions, and provide
  qualitative coaching.
* **AI Equity Auditors**: Automated systems that flag statistical anomalies in
  real-time.
* **Data Engineering**: Maintain the integrity of the Feature Store pipelines.

## 5. The NEF Process

### Phase 1: Automated Alignment (Quarter Start)

**Objective**: Establish clear, interconnected goals based on hard data.

* **Metric Selection**: Employees do not "write" goals. Instead, they select 3-5
  **Predefined Metrics** from the `FeatureMetadata` library (e.g.,
  `UserEngagement.sessions_last_7d`, `Finance.mrr_contribution`).
* **Automated Weighting**: The system automatically assigns weights based on Role
  Code (e.g., `SWEN1002` defaults to 50% Technical Output, 30% Team, 20%
  Company).
* **Baseline Ledger**: Initial metrics are recorded on the immutable ledger.

### Phase 2: Continuous Automated Tracking (Ongoing)

**Objective**: Real-time monitoring via automated data ingestion.

* **Data Streams**: The system continuously ingests data into the
  `company.features.v1` tables via SQL pipelines (e.g.,
  `pipelines/features/sql/`).
  * **Engineering**: Commits, PR reviews, Test coverage (via CI/CD logs).
  * **Product**: User engagement segments (via `engagement.sql`).
  * **Sales**: MRR contribution (via `monthly_recurring_revenue.sql`).
* **Feedback Nexus**: Structured micro-feedback is quantified and aggregated
  automatically.

### Phase 3: Algorithmic Evaluation (Quarter End)

**Objective**: Synthesize data into a holistic Score (0-100).

* **Scoring Algorithm**: Raw feature values are normalized and weighted to
  produce the Final Score.
* **Calibration**: Automated statistical analysis compares scores across cohorts
  to detect and correct distribution anomalies.

### Phase 4: Outcomes (Post-Quarter)

* **Rewards**: Compensation adjustments are programmatically determined by the
  Final Score.

## 6. Implementation Requirements

* **Tech Stack**:
  * **Feature Store**: Google BigQuery (`company.features.v1`).
  * **Orchestrator**: Automated pipelines (e.g., Airflow/Spark) running SQL transformations.
  * **Ledger**: Immutable audit log of all score calculations.

## 7. Violations & Exceptions

* **Data Manipulation**: Attempting to artificially inflate metrics (e.g.,
  "gaming" commit counts) is a violation of the Code of Conduct.

## 8. Revision History

* **Version 1.1**: Updated to emphasize automation and technical metric definitions.
* **Version 1.0**: Initial release.

## 9. Technical Metric Calculation & Logic

All NEF metrics are derived from the **Company Feature Store**, defined in
Protocol Buffers and calculated via standardized SQL pipelines.

### 9.1 Metric Source: Feature Store (`company.features.v1`)

Metrics are strictly typed and defined in `.proto` files to ensure consistency.

* **Domain**: `company.features.v1`
* **Storage**: BigQuery Tables (e.g., `derived.sessions`, `raw.auth_logs`)

### 9.2 Calculation Logic: User Engagement Example

For roles tied to product performance, the **Engagement Score** is calculated
using the `calculate_frequency_segment` SQL function found in
`pipelines/features/sql/user/engagement.sql`.

**SQL Logic**:

```sql
CREATE TEMP FUNCTION calculate_frequency_segment(sessions_last_7d INT64)
RETURNS STRING AS (
    CASE
        WHEN sessions_last_7d >= 5 THEN 'Daily'
        WHEN sessions_last_7d >= 1 THEN 'Weekly'
        ELSE 'Sporadic'
    END
);
```

**Scoring Conversion**:

* **Daily**: 100 Points
* **Weekly**: 75 Points
* **Sporadic**: 25 Points

### 9.3 Calculation Logic: Financial Impact Example

For revenue-generating roles, impact is measured using the
`micros_to_dollars` conversion to ensure precision.

**Standardization**:

* **Input**: Integer micros (from `company.finance.v1.PayrollRecord` or Sales
  Ledger).
* **Transformation**: `CAST(amount_micros AS FLOAT64) / 1000000.0`
* **Score**: `(Actual Revenue / Target Revenue) * 100` (Capped at 120%).

### 9.4 Normalization Algorithm

To ensure fairness across different metric types (e.g., Dollars vs. Commits),
all raw values are normalized before weighting.

**Formula**:
`NormalizedScore = (RawValue - MinThreshold) / (MaxTarget - MinThreshold) * 100`

* **MinThreshold**: Defined per role in `docs/job_roles/` (e.g., Minimum
  expected commits).
* **MaxTarget**: Stretch goal defined in the Baseline Ledger.
