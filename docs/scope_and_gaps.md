# Scope and gaps — Yelp secondary dataset

Status: DRAFT. Nothing measured yet — this file gets filled in as real runs happen,
same rule as the sibling BRFSS project (`D:\data-lab2\docs\scope_and_gaps.md`).

## What this is, and how it relates to the main project

The team brief (`docs/brief.md`) asks for 3 datasets: Primary, Secondary, Stretch.
The BRFSS project (`D:\data-lab2`) covers the core Databricks-vs-Snowflake comparison
but only ever used one dataset. This repo is the **Secondary** slot: "semi-structured,
nested fields, variable schema between records."

## Source

- Kaggle: `yelp-dataset/yelp-dataset` (https://www.kaggle.com/datasets/yelp-dataset/yelp-dataset)
- 6.99M reviews, 150,346 businesses, 11 metro areas, 4.37GB compressed (confirmed via
  `kaggle datasets list -s yelp`, 2026-09-29)
- **License: academic/research use only, not commercial.** Recorded here plainly per
  the brief's own R2 requirement ("a short licence summary per dataset").
- Files: business.json, review.json, user.json, checkin.json, tip.json, photo.json
  (one JSON object per line each - JSONL, not a single JSON array)

## Deviations from the brief (to fill in as we go)

Following the same pattern as `D:\data-lab2\docs\scope_and_gaps.md` - anything the
brief asks for that we can't or won't do gets recorded here plainly, not hidden.

| # | Brief says | What we have | Impact |
|---|-----------|--------------|--------|
| (none yet) | | | |

## Data problems found (to fill in after profiling)

## Out of scope for this delivery
