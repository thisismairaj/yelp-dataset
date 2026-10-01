# Yelp Open Dataset — Secondary Dataset Pipeline

Secondary dataset (semi-structured, nested fields, variable schema between records)
for a team brief comparing Databricks and Snowflake as a data platform. Sibling
repos: [data-lab2](https://github.com/thisismairaj/data-lab2) (BRFSS, the core
platform comparison), [fhir-dataset](https://github.com/thisismairaj/fhir-dataset)
(deeply nested + streaming ingestion).

**Source:** [Kaggle - Yelp Dataset](https://www.kaggle.com/datasets/yelp-dataset/yelp-dataset)
(6.99M reviews, 150,346 businesses, academic/research license only).

**Target platform:** Databricks Trial workspace.

## Layout
- `sql/databricks/` — bronze/silver/gold SQL
- `scripts/` — upload/generator scripts
- `data/raw/` — local download staging
