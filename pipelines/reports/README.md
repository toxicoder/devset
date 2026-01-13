# Business Intelligence & Reports

This directory contains SQL pipelines used to generate critical business reports for internal and external stakeholders.
These pipelines aggregate data from various domains (Finance, Sales, Marketing, HR, Engineering, Product) to provide actionable insights.

## Structure

The directory is organized by business domain:

*   **finance/**: Revenue, P&L, Vendor Spend, Payroll.
*   **sales/**: Funnel Conversion, Regional Performance, Deal Velocity.
*   **marketing/**: CAC, Campaign ROI, Channel Performance.
*   **hr/**: Headcount, Turnover, Diversity Metrics.
*   **engineering/**: DORA Metrics, Cloud Costs, Incident Trends.
*   **product/**: Retention, Feature Adoption, DAU/MAU.
*   **executive/**: High-level aggregated reports for Leadership (QBRs, Board Decks).

## Usage

These scripts are designed to be run against the corporate data warehouse (e.g., BigQuery).
They typically query `company_{domain}_v1_{entity}` tables which correspond to the Protocol Buffer definitions in `protos/`.

## Standards

*   **Syntax**: Google BigQuery SQL.
*   **Style**: readable, commented, utilizing CTEs for complex logic.
*   **Naming**: `snake_case` for filenames and column aliases.
