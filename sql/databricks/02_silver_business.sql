-- Databricks Trial: silver for Yelp business, built from workspace.yelp_bronze.business.
-- Same 4-stage shape as the BRFSS project (staged -> checked -> keyed -> publish), but
-- this is the first time REJECT gets used for real: BRFSS's CSVs never had a row that
-- was structurally unreadable (read_files either parses a CSV row or it doesn't exist).
-- JSON gives us a genuine case: from_json returns NULL for the whole struct when a line
-- isn't valid JSON at all - that's the brief's "Rejected: structurally unreadable, no
-- safe fix, logged only" outcome, distinct from "Quarantined" (readable, but fails a
-- rule). Same quarantine table SHAPE reused for both, just severity='reject' vs
-- severity='quarantine' - exactly what the brief's own table anticipates.

CREATE SCHEMA IF NOT EXISTS workspace.yelp_silver;

-- ---- Step 1: staged - parse the JSON, nothing else yet ----
-- attributes and hours are typed as MAP<STRING,STRING>, not a fixed STRUCT, because
-- their keys genuinely vary business to business (confirmed: one business had 1
-- attribute key, another had 15) - a MAP has no fixed schema, so it doesn't fight the
-- data's real variable shape the way a STRUCT with named fields would.
CREATE OR REPLACE TABLE workspace.yelp_silver._staged_business AS
SELECT
  raw_json,
  _source_file, _loaded_at, _run_id,
  from_json(raw_json,
    'STRUCT<business_id:STRING, name:STRING, address:STRING, city:STRING, state:STRING, ' ||
    'postal_code:STRING, latitude:DOUBLE, longitude:DOUBLE, stars:DOUBLE, review_count:BIGINT, ' ||
    'is_open:INT, attributes:MAP<STRING,STRING>, categories:STRING, hours:MAP<STRING,STRING>>'
  ) AS parsed
FROM workspace.yelp_bronze.business;

-- ---- Step 2: checked - add hit_<rule> flags ----
CREATE OR REPLACE TABLE workspace.yelp_silver._checked_business AS
SELECT *,
  -- REJECT: from_json gives back NULL for the whole struct when the line isn't valid
  -- JSON at all (permissive mode, the Spark default) - structurally unreadable, not a
  -- rule failure, so this is Reject, not Quarantine.
  (parsed IS NULL)                                                      AS hit_reject_bad_json,
  -- Q1: valid JSON, but the primary key itself is missing - can't publish an unkeyed row.
  (parsed IS NOT NULL AND parsed.business_id IS NULL)                   AS hit_q1_missing_key,
  -- C1: is_open is a 2-value code (0/1); anything else means a data problem, same
  -- principle as BRFSS's C1 (a code outside the defined set is never guessed at).
  (parsed IS NOT NULL AND parsed.is_open IS NOT NULL
     AND parsed.is_open NOT IN (0,1))                                   AS hit_c1_is_open,
  -- R1: implausible coordinates. Real range check (not hardcoded to the 11 known metro
  -- areas, since a real business could legitimately be somewhere new) - same spirit as
  -- BRFSS's R1 BMI range: a real bound catches encoding errors without guessing at a
  -- "correct" value.
  (parsed IS NOT NULL AND parsed.latitude IS NOT NULL
     AND (parsed.latitude NOT BETWEEN -90 AND 90
          OR parsed.longitude NOT BETWEEN -180 AND 180))                AS hit_r1_latlong
FROM workspace.yelp_silver._staged_business;

-- ---- Step 3: keyed - K1 duplicate business_id (only meaningful for rows with a key) ----
CREATE OR REPLACE TABLE workspace.yelp_silver._keyed_business AS
SELECT *,
  (parsed IS NOT NULL AND parsed.business_id IS NOT NULL
     AND count(*) OVER (PARTITION BY parsed.business_id) > 1)           AS hit_k1_dup_pk
FROM workspace.yelp_silver._checked_business;

-- ---- Step 4: publish ----

-- Rejected: structurally unreadable. raw_payload is the whole broken line (nothing else
-- to show), since there's no parsed struct to pull fields from.
CREATE OR REPLACE TABLE workspace.yelp_silver.business_quarantine AS
SELECT
  NULL AS record_id, 'yelp_business' AS dataset_id, _run_id AS run_id,
  'REJECT_BAD_JSON' AS rule_id, 'reject' AS severity,
  raw_json AS raw_payload,
  'Line is not valid JSON - structurally unreadable' AS reason,
  'new' AS status, CAST(NULL AS STRING) AS resolved_by
FROM workspace.yelp_silver._keyed_business
WHERE hit_reject_bad_json

UNION ALL

-- Quarantined: valid JSON, failed a rule. Same concat_ws pattern as BRFSS (each CASE
-- returns NULL when its rule didn't fire; concat_ws silently skips NULLs).
SELECT
  parsed.business_id AS record_id, 'yelp_business' AS dataset_id, _run_id AS run_id,
  concat_ws(',',
    CASE WHEN hit_q1_missing_key THEN 'Q1' END,
    CASE WHEN hit_c1_is_open THEN 'C1' END,
    CASE WHEN hit_r1_latlong THEN 'R1' END,
    CASE WHEN hit_k1_dup_pk THEN 'K1' END
  ) AS rule_id,
  'quarantine' AS severity,
  to_json(named_struct('business_id', parsed.business_id, 'name', parsed.name,
                        'is_open', parsed.is_open, 'latitude', parsed.latitude,
                        'longitude', parsed.longitude))                 AS raw_payload,
  'Failed one or more contract rules - see rule_id' AS reason,
  'new' AS status, CAST(NULL AS STRING) AS resolved_by
FROM workspace.yelp_silver._keyed_business
WHERE NOT hit_reject_bad_json
  AND (hit_q1_missing_key OR hit_c1_is_open OR hit_r1_latlong OR hit_k1_dup_pk);

-- Clean: passed every rule. categories gets split here - a deterministic, reversible
-- correction (same class as BRFSS's D1/Z1), not a guess: comma-split + trim, with the
-- original string kept alongside so nothing is lost.
CREATE OR REPLACE TABLE workspace.yelp_silver.business_clean AS
SELECT
  parsed.business_id, parsed.name, parsed.address, parsed.city, parsed.state,
  parsed.postal_code, parsed.latitude, parsed.longitude, parsed.stars,
  parsed.review_count, parsed.is_open,
  parsed.attributes,                                                    -- MAP<STRING,STRING>, kept as-is
  parsed.categories                              AS categories_raw,     -- original, never lost
  transform(split(parsed.categories, ',\\s*'), x -> trim(x)) AS categories_array,  -- correction: C1_CATEGORIES_SPLIT
  parsed.hours,
  'C1_CATEGORIES_SPLIT' AS corrections,
  _run_id
FROM workspace.yelp_silver._keyed_business
WHERE NOT (hit_reject_bad_json OR hit_q1_missing_key OR hit_c1_is_open OR hit_r1_latlong OR hit_k1_dup_pk);

-- ---- Publication gate checks ----

-- Every bronze row ends in exactly one outcome; counts must sum to bronze's total.
SELECT
  (SELECT count(*) FROM workspace.yelp_silver.business_clean) AS clean,
  (SELECT count(*) FROM workspace.yelp_silver.business_quarantine WHERE severity = 'quarantine') AS quarantined,
  (SELECT count(*) FROM workspace.yelp_silver.business_quarantine WHERE severity = 'reject') AS rejected,
  (SELECT count(*) FROM workspace.yelp_bronze.business) AS bronze_rows;

-- Key uniqueness in the published clean table - expect 0.
SELECT count(*) - count(DISTINCT business_id) FROM workspace.yelp_silver.business_clean;

-- Quick eyeball: does the categories split actually work?
SELECT categories_raw, categories_array FROM workspace.yelp_silver.business_clean LIMIT 3;

-- Rule breakdown - which rules actually fire, and how often (mirrors BRFSS's own gate check)
SELECT severity, rule_id, count(*) FROM workspace.yelp_silver.business_quarantine GROUP BY 1,2 ORDER BY 1,2;
