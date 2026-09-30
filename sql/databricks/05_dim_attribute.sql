-- Databricks Trial: dim_attribute + bridge_business_attribute, same pattern as
-- dim_category/bridge_business_category (04_star_schema_business.sql) - a business has
-- MANY attribute keys (1 key on one business, 15 on another, confirmed earlier), and an
-- attribute key like "WiFi" applies to MANY businesses. Same many-to-many shape,
-- same fix: a dimension for the attribute NAME, a bridge holding the per-business VALUE.
--
-- dim_attribute is keyed by attribute_name only, not name+value - WiFi's actual values
-- ("True","False","u'no'","free",...) vary continuously, so they're not a fixed
-- dimension the way category names are; they belong in the bridge as data, not as rows
-- of the dimension itself.
--
-- Known, documented limitation carried over from the silver design: a handful of
-- attribute keys (BusinessParking, Ambience, Music, GoodForMeal, BestNights,
-- HairSpecializesIn - Yelp's own nested-attribute keys) hold a VALUE that is itself a
-- serialized Python-dict-repr string (e.g. "{'garage': False, 'street': False}"), not a
-- valid JSON value. bridge_business_attribute stores that string as-is, same as
-- everywhere else in this project's "never silently fix, never silently drop" rule -
-- a consumer querying BusinessParking specifically will see the raw string and needs a
-- second parsing step, which is out of scope until something actually needs it.

CREATE SCHEMA IF NOT EXISTS workspace.yelp_gold;

CREATE OR REPLACE TABLE workspace.yelp_gold.dim_attribute AS
SELECT
  row_number() OVER (ORDER BY attribute_name) AS attribute_id,
  attribute_name
FROM (
  SELECT DISTINCT explode(map_keys(attributes)) AS attribute_name
  FROM workspace.yelp_gold.fact_business
  WHERE attributes IS NOT NULL
);

-- LATERAL VIEW resolved in its own subquery first, then joined - same fix already
-- learned building bridge_business_category (a plain JOIN can't directly follow a
-- LATERAL VIEW in one FROM clause).
CREATE OR REPLACE TABLE workspace.yelp_gold.bridge_business_attribute AS
SELECT b.business_id, d.attribute_id, b.attribute_value
FROM (
  SELECT business_id, attribute_name, attribute_value
  FROM workspace.yelp_gold.fact_business
  LATERAL VIEW explode(attributes) AS attribute_name, attribute_value
  WHERE attributes IS NOT NULL
) b
JOIN workspace.yelp_gold.dim_attribute d ON d.attribute_name = b.attribute_name;

-- ---- Verification ----

SELECT count(*) FROM workspace.yelp_gold.dim_attribute;               -- how many distinct attribute keys actually exist
SELECT count(*) FROM workspace.yelp_gold.bridge_business_attribute;   -- total (business, attribute) pairs across all businesses

-- Reconciliation: bridge row count should equal the sum of attribute-map sizes across
-- all businesses - proves nothing was dropped or duplicated during the explode+join.
SELECT sum(size(attributes)) FROM workspace.yelp_gold.fact_business WHERE attributes IS NOT NULL;

-- The actual answer to the question this was built for: average rating per attribute
-- value, for a few real attributes - one query covers what used to need a separate
-- map-lookup query per attribute.
SELECT d.attribute_name, b.attribute_value, count(*) AS business_count, round(avg(f.stars), 2) AS avg_stars
FROM workspace.yelp_gold.bridge_business_attribute b
JOIN workspace.yelp_gold.dim_attribute d ON d.attribute_id = b.attribute_id
JOIN workspace.yelp_gold.fact_business f ON f.business_id = b.business_id
WHERE d.attribute_name IN ('OutdoorSeating', 'WiFi', 'GoodForKids', 'RestaurantsDelivery')
GROUP BY d.attribute_name, b.attribute_value
HAVING count(*) >= 30
ORDER BY d.attribute_name, business_count DESC;

-- List every distinct attribute name that actually exists (not assumed from memory)
SELECT attribute_name FROM workspace.yelp_gold.dim_attribute ORDER BY attribute_name;
