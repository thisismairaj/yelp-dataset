-- Databricks Trial: gold.category_summary, built from workspace.yelp_silver.business_clean.
-- Answers: does rating vary by category, and does closure rate vary by category?
-- (two of the real business-insight questions discussed for this dataset).
--
-- Design note, different from every BRFSS gold table: a business can belong to
-- SEVERAL categories at once (categories_array), so exploding it means one business
-- contributes to multiple category rows - unlike BRFSS's diabetes_code buckets, which
-- were mutually exclusive. That's correct here (a business really is both "Mexican"
-- and "Restaurants"), but it means category counts don't sum to 150,346 - documented
-- below, not a bug.
--
-- Small-cell suppression carried over from the BRFSS risk-stacking table's own habit:
-- flag any category with too few businesses to trust rather than silently show it.

CREATE SCHEMA IF NOT EXISTS workspace.yelp_gold;

CREATE OR REPLACE TABLE workspace.yelp_gold.category_summary AS
SELECT
  category,
  count(*)                                            AS business_count,
  round(avg(stars), 2)                                AS avg_stars,
  sum(review_count)                                   AS total_reviews,
  count(*) FILTER (WHERE is_open = 1)                  AS open_count,
  count(*) FILTER (WHERE is_open = 0)                  AS closed_count,
  round(100.0 * count(*) FILTER (WHERE is_open = 0) / count(*), 2)  AS closed_rate_pct,
  (count(*) < 30)                                      AS small_cell_suppressed
FROM workspace.yelp_silver.business_clean
LATERAL VIEW explode(categories_array) AS category
WHERE category != ''   -- a few businesses have an empty category array; drop the empty string, not the business
GROUP BY category
ORDER BY business_count DESC;

-- ---- Verification ----

-- Row count sanity: number of distinct categories, not a business count (documented above)
SELECT count(*) FROM workspace.yelp_gold.category_summary;

-- Reconciliation check: sum of business_count is EXPECTED to exceed 150346, since most
-- businesses have multiple categories - this proves the multi-category design is
-- working as intended, not a duplication bug. Compare against a distinct business count
-- to show the multiplier.
SELECT sum(business_count) AS category_rows_total FROM workspace.yelp_gold.category_summary;
SELECT count(*) AS distinct_businesses FROM workspace.yelp_silver.business_clean;
SELECT round(avg(size(categories_array)), 2) AS avg_categories_per_business
FROM workspace.yelp_silver.business_clean;

-- The actual findings: top 20 categories by volume, with rating and closure rate side by side
SELECT category, business_count, avg_stars, closed_rate_pct, small_cell_suppressed
FROM workspace.yelp_gold.category_summary
ORDER BY business_count DESC
LIMIT 20;

-- Highest and lowest rated categories with enough volume to trust (>= 30 businesses)
SELECT category, business_count, avg_stars, closed_rate_pct
FROM workspace.yelp_gold.category_summary
WHERE NOT small_cell_suppressed
ORDER BY avg_stars DESC
LIMIT 10;

SELECT category, business_count, avg_stars, closed_rate_pct
FROM workspace.yelp_gold.category_summary
WHERE NOT small_cell_suppressed
ORDER BY avg_stars ASC
LIMIT 10;

-- Highest and lowest closure rate, same volume floor
SELECT category, business_count, avg_stars, closed_rate_pct
FROM workspace.yelp_gold.category_summary
WHERE NOT small_cell_suppressed
ORDER BY closed_rate_pct DESC
LIMIT 10;
