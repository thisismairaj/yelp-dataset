-- Databricks Trial: silver for Yelp review, built from workspace.yelp_bronze.review.
-- Same 4-stage shape as business's silver. review.json is much flatter than
-- business.json (confirmed by looking at real rows first, same habit that already
-- caught 2 mistakes on this dataset) - no MAP/array fields, just scalars plus a date
-- string. The one genuinely new rule here: a real referential-integrity check
-- (business_id must exist in business_clean) - a rule type this project has talked
-- about (the brief's own "Referential integrity failure" quarantine category) but
-- never actually enforced as its own rule before now.

CREATE SCHEMA IF NOT EXISTS workspace.yelp_silver;

-- ---- Step 1: staged - parse JSON, cast the date string to a real timestamp ----
CREATE OR REPLACE TABLE workspace.yelp_silver._staged_review AS
SELECT
  raw_json, _source_file, _loaded_at, _run_id,
  from_json(raw_json,
    'STRUCT<review_id:STRING, user_id:STRING, business_id:STRING, stars:DOUBLE, ' ||
    'useful:INT, funny:INT, cool:INT, text:STRING, date:STRING>'
  ) AS parsed
FROM workspace.yelp_bronze.review;

-- ---- Step 2: checked - add hit_<rule> flags ----
CREATE OR REPLACE TABLE workspace.yelp_silver._checked_review AS
SELECT *,
  (parsed IS NULL)                                                     AS hit_reject_bad_json,
  (parsed IS NOT NULL AND parsed.review_id IS NULL)                    AS hit_q1_missing_key,
  -- R1: stars outside the plausible 1-5 range - same "implausible value" principle as
  -- BRFSS's BMI range and business's lat/long range checks.
  (parsed IS NOT NULL AND parsed.stars IS NOT NULL
     AND parsed.stars NOT BETWEEN 1 AND 5)                             AS hit_r1_stars,
  -- D3: the date string doesn't parse as a real timestamp under Yelp's own format.
  (parsed IS NOT NULL AND parsed.date IS NOT NULL
     AND try_to_timestamp(parsed.date, 'yyyy-MM-dd HH:mm:ss') IS NULL) AS hit_d3_bad_date
FROM workspace.yelp_silver._staged_review;

-- ---- Step 3: keyed - K1 duplicate review_id ----
CREATE OR REPLACE TABLE workspace.yelp_silver._keyed_review AS
SELECT *,
  (parsed IS NOT NULL AND parsed.review_id IS NOT NULL
     AND count(*) OVER (PARTITION BY parsed.review_id) > 1)            AS hit_k1_dup_pk
FROM workspace.yelp_silver._checked_review;

-- ---- Step 4: FK check - business_id must exist in business_clean. Done as its own
-- step (a LEFT JOIN anti-join, not NOT IN, for a 6.99M-row table against 150K
-- businesses) rather than folded into _checked_review, since it needs a join, not just
-- a per-row expression like every other rule here.
CREATE OR REPLACE TABLE workspace.yelp_silver._fk_checked_review AS
SELECT k.*, (b.business_id IS NULL AND k.parsed IS NOT NULL) AS hit_fk_business
FROM workspace.yelp_silver._keyed_review k
LEFT JOIN workspace.yelp_silver.business_clean b ON b.business_id = k.parsed.business_id;

-- ---- Step 5: publish ----

CREATE OR REPLACE TABLE workspace.yelp_silver.review_quarantine AS
SELECT
  NULL AS record_id, 'yelp_review' AS dataset_id, _run_id AS run_id,
  'REJECT_BAD_JSON' AS rule_id, 'reject' AS severity,
  raw_json AS raw_payload,
  'Line is not valid JSON - structurally unreadable' AS reason,
  'new' AS status, CAST(NULL AS STRING) AS resolved_by
FROM workspace.yelp_silver._fk_checked_review
WHERE hit_reject_bad_json

UNION ALL

SELECT
  parsed.review_id AS record_id, 'yelp_review' AS dataset_id, _run_id AS run_id,
  concat_ws(',',
    CASE WHEN hit_q1_missing_key THEN 'Q1' END,
    CASE WHEN hit_r1_stars THEN 'R1' END,
    CASE WHEN hit_d3_bad_date THEN 'D3' END,
    CASE WHEN hit_k1_dup_pk THEN 'K1' END,
    CASE WHEN hit_fk_business THEN 'FK1' END
  ) AS rule_id,
  'quarantine' AS severity,
  to_json(named_struct('review_id', parsed.review_id, 'business_id', parsed.business_id,
                        'stars', parsed.stars, 'date', parsed.date))   AS raw_payload,
  'Failed one or more contract rules - see rule_id' AS reason,
  'new' AS status, CAST(NULL AS STRING) AS resolved_by
FROM workspace.yelp_silver._fk_checked_review
WHERE NOT hit_reject_bad_json
  AND (hit_q1_missing_key OR hit_r1_stars OR hit_d3_bad_date OR hit_k1_dup_pk OR hit_fk_business);

CREATE OR REPLACE TABLE workspace.yelp_silver.review_clean AS
SELECT
  parsed.review_id, parsed.user_id, parsed.business_id, parsed.stars,
  parsed.useful, parsed.funny, parsed.cool, parsed.text,
  try_to_timestamp(parsed.date, 'yyyy-MM-dd HH:mm:ss') AS review_date,
  _run_id
FROM workspace.yelp_silver._fk_checked_review
WHERE NOT (hit_reject_bad_json OR hit_q1_missing_key OR hit_r1_stars OR hit_d3_bad_date
           OR hit_k1_dup_pk OR hit_fk_business);

-- ---- Publication gate checks ----

SELECT
  (SELECT count(*) FROM workspace.yelp_silver.review_clean) AS clean,
  (SELECT count(*) FROM workspace.yelp_silver.review_quarantine WHERE severity = 'quarantine') AS quarantined,
  (SELECT count(*) FROM workspace.yelp_silver.review_quarantine WHERE severity = 'reject') AS rejected,
  (SELECT count(*) FROM workspace.yelp_bronze.review) AS bronze_rows;

SELECT count(*) - count(DISTINCT review_id) FROM workspace.yelp_silver.review_clean;   -- expect 0

SELECT rule_id, count(*) FROM workspace.yelp_silver.review_quarantine
WHERE severity = 'quarantine' GROUP BY rule_id ORDER BY 2 DESC;
