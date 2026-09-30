-- Databricks Trial: star schema (fact + dimension) for Yelp business data, alongside
-- the pre-aggregated gold.category_summary already built. Same source (silver.
-- business_clean), different shape - built to compare against, not replace, since both
-- are legitimate and this project wants to show the trade-off, not just assert it.
--
-- dim_category: one row per distinct category, a surrogate integer key (category_id)
-- plus the natural key (category_name) - standard practice so a future rename doesn't
-- ripple through every fact row, even though nothing here renames categories today.
--
-- bridge_business_category: the many-to-many join table. A business has several
-- categories (avg 4.45) - you cannot put category_id directly on fact_business without
-- either fanning out fact_business itself (duplicating every business row per category,
-- which corrupts any aggregate that isn't category-scoped, like a plain COUNT(*) of
-- businesses) or losing the relationship. A bridge table is the standard fix: fact
-- stays at "one row per business," the many-to-many lives in its own table.
--
-- fact_business: one row per business, the actual measures (stars, review_count,
-- is_open) plus geography as flat attributes, not a separate dimension - city/state
-- don't fan out (one business has exactly one address), so a join buys nothing here.
-- This is a legitimate "degenerate dimension" - not every attribute needs its own table.

CREATE SCHEMA IF NOT EXISTS workspace.yelp_gold;

CREATE OR REPLACE TABLE workspace.yelp_gold.dim_category AS
SELECT
  row_number() OVER (ORDER BY category) AS category_id,
  category                              AS category_name
FROM (
  SELECT DISTINCT explode(categories_array) AS category
  FROM workspace.yelp_silver.business_clean
)
WHERE category != '';

-- LATERAL VIEW has to be fully resolved in its own subquery before joining onto
-- dim_category - a plain JOIN can't follow a LATERAL VIEW directly in one FROM clause
-- (real syntax error hit here, not a style choice).
CREATE OR REPLACE TABLE workspace.yelp_gold.bridge_business_category AS
SELECT b.business_id, d.category_id
FROM (
  SELECT business_id, category
  FROM workspace.yelp_silver.business_clean
  LATERAL VIEW explode(categories_array) AS category
) b
JOIN workspace.yelp_gold.dim_category d ON d.category_name = b.category
WHERE b.category != '';

CREATE OR REPLACE TABLE workspace.yelp_gold.fact_business AS
SELECT
  business_id, name, city, state, postal_code, latitude, longitude,
  stars, review_count, is_open, attributes, hours
FROM workspace.yelp_silver.business_clean;

-- ---- Verification ----

-- Row counts: fact should be exactly 150346 (one row per business, no fan-out).
SELECT count(*) FROM workspace.yelp_gold.fact_business;                      -- expect 150346
SELECT count(*) FROM workspace.yelp_gold.dim_category;                       -- expect 1311, same as category_summary's row count
SELECT count(*) FROM workspace.yelp_gold.bridge_business_category;           -- expect 668592, same as category_summary's business_count sum

-- The category-level numbers, now derived via fact+bridge+dim joins instead of a
-- stored pre-aggregated table. This exact query was originally run as a diff against
-- gold.category_summary to PROVE the two designs agreed (0 mismatches across all 1311
-- categories, 2026-09-30) before category_summary was retired and dropped - see
-- 03_gold_category_summary.sql's superseded note. That comparison step is gone now
-- since there's nothing left to diff against; this is the query that replaces it going
-- forward for any "rating/closure by category" question.
SELECT
  d.category_name AS category,
  count(*)                                                             AS business_count,
  round(avg(f.stars), 2)                                                AS avg_stars,
  round(100.0 * count(*) FILTER (WHERE f.is_open = 0) / count(*), 2)    AS closed_rate_pct
FROM workspace.yelp_gold.fact_business f
JOIN workspace.yelp_gold.bridge_business_category b ON b.business_id = f.business_id
JOIN workspace.yelp_gold.dim_category d ON d.category_id = b.category_id
GROUP BY d.category_name
ORDER BY business_count DESC
LIMIT 20;
