-- Databricks Trial: fact_review, extending the star schema (04_star_schema_business.sql)
-- with the review grain. One row per review (6.99M) - the FK check already proved every
-- business_id here exists in fact_business, so this joins cleanly with no orphans.
-- user_id stays a plain column, not yet a proper dimension key - no dim_user/fact_user
-- built yet (user.json only has bronze so far, no silver), so there's nothing to join
-- it to. Recorded here plainly rather than pretending it's already modeled.

CREATE OR REPLACE TABLE workspace.yelp_gold.fact_review AS
SELECT
  review_id, business_id, user_id, stars, useful, funny, cool, text, review_date
FROM workspace.yelp_silver.review_clean;

-- ---- Verification ----

SELECT count(*) FROM workspace.yelp_gold.fact_review;                                -- expect 6990280

-- Every business_id in fact_review must exist in fact_business - re-confirm the join
-- is clean at the star-schema layer too, not just in silver.
SELECT count(*) FROM workspace.yelp_gold.fact_review r
LEFT JOIN workspace.yelp_gold.fact_business b ON b.business_id = r.business_id
WHERE b.business_id IS NULL;                                                          -- expect 0

-- The payoff: a question needing BOTH review-level and category-level context, in one
-- query, no new gold table - review volume and average rating by category over time.
SELECT year(r.review_date) AS review_year, d.category_name,
       count(*) AS review_count, round(avg(r.stars), 2) AS avg_review_stars
FROM workspace.yelp_gold.fact_review r
JOIN workspace.yelp_gold.bridge_business_category bc ON bc.business_id = r.business_id
JOIN workspace.yelp_gold.dim_category d ON d.category_id = bc.category_id
WHERE d.category_name IN ('Restaurants', 'Nightlife', 'Shopping')
GROUP BY review_year, d.category_name
HAVING count(*) >= 30
ORDER BY d.category_name, review_year;
