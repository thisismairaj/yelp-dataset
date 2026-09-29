# Yelp Open Dataset — Secondary Dataset Pipeline

Secondary dataset (semi-structured, nested fields, variable schema between records)
for the team brief being worked on in the sibling repo `D:\data-lab2`. See
`docs/brief.md` for the full brief and `docs/scope_and_gaps.md` for what's actually
been built vs. what the brief asks for.

**Source:** [Kaggle - Yelp Dataset](https://www.kaggle.com/datasets/yelp-dataset/yelp-dataset)
(6.99M reviews, 150,346 businesses, academic/research license only).

**Target platform:** Databricks Trial workspace.

## Layout
- `docs/` — brief, schema contract, scope/gaps, learning log
- `sql/databricks/` — bronze/silver/gold SQL
- `scripts/` — upload/generator scripts
- `data/raw/` — local download staging (git-ignored, not committed)
