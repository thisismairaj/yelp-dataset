-- Databricks Trial: silver for Yelp checkin, built from workspace.yelp_bronze.checkin.
-- Different shape from every other silver table so far: bronze has ONE ROW PER
-- BUSINESS, with every checkin timestamp for that business packed into a single
-- comma-separated string (confirmed by looking at a real row: one business, 6
-- timestamps in one field). Silver here does more than split-and-correct - it
-- EXPLODES that string into one row per actual checkin event, changing the grain
-- from "business" to "checkin instant". That's a real, deliberate transformation,
-- not just a correction like the categories/elite/friends splits - documented plainly
-- since it changes what a "row" means between bronze and silver for this one table.

CREATE SCHEMA IF NOT EXISTS workspace.yelp_silver;

CREATE OR REPLACE TABLE workspace.yelp_silver._staged_checkin AS
SELECT
  raw_json, _source_file, _loaded_at, _run_id,
  from_json(raw_json, 'STRUCT<business_id:STRING, date:STRING>') AS parsed
FROM workspace.yelp_bronze.checkin;

CREATE OR REPLACE TABLE workspace.yelp_silver._checked_checkin AS
SELECT *,
  (parsed IS NULL)                                                    AS hit_reject_bad_json,
  (parsed IS NOT NULL AND parsed.business_id IS NULL)                 AS hit_q1_missing_key
FROM workspace.yelp_silver._staged_checkin;

-- Reject/quarantine rows never reach the explode step - they have no reliable
-- timestamp list to explode in the first place.
CREATE OR REPLACE TABLE workspace.yelp_silver.checkin_quarantine AS
SELECT
  NULL AS record_id, 'yelp_checkin' AS dataset_id, _run_id AS run_id,
  'REJECT_BAD_JSON' AS rule_id, 'reject' AS severity,
  raw_json AS raw_payload, 'Line is not valid JSON - structurally unreadable' AS reason,
  'new' AS status, CAST(NULL AS STRING) AS resolved_by
FROM workspace.yelp_silver._checked_checkin
WHERE hit_reject_bad_json

UNION ALL

SELECT
  NULL AS record_id, 'yelp_checkin' AS dataset_id, _run_id AS run_id,
  'Q1' AS rule_id, 'quarantine' AS severity,
  raw_json AS raw_payload, 'Missing business_id' AS reason,
  'new' AS status, CAST(NULL AS STRING) AS resolved_by
FROM workspace.yelp_silver._checked_checkin
WHERE NOT hit_reject_bad_json AND hit_q1_missing_key;

-- Explode first, then FK-check with a LEFT JOIN (not an inner JOIN, which would
-- silently drop non-matching rows instead of quarantining them - caught before
-- running, not after).
CREATE OR REPLACE TABLE workspace.yelp_silver._exploded_checkin AS
SELECT parsed.business_id AS business_id, trim(checkin_ts) AS checkin_ts, _run_id
FROM workspace.yelp_silver._checked_checkin
LATERAL VIEW explode(split(parsed.date, ',')) AS checkin_ts
WHERE NOT hit_reject_bad_json AND NOT hit_q1_missing_key;

INSERT INTO workspace.yelp_silver.checkin_quarantine
SELECT
  NULL AS record_id, 'yelp_checkin' AS dataset_id, e._run_id AS run_id,
  'FK1' AS rule_id, 'quarantine' AS severity,
  to_json(named_struct('business_id', e.business_id, 'checkin_ts', e.checkin_ts)) AS raw_payload,
  'business_id not found in business_clean' AS reason,
  'new' AS status, CAST(NULL AS STRING) AS resolved_by
FROM workspace.yelp_silver._exploded_checkin e
LEFT JOIN workspace.yelp_silver.business_clean b ON b.business_id = e.business_id
WHERE b.business_id IS NULL;

CREATE OR REPLACE TABLE workspace.yelp_silver.checkin_clean AS
SELECT e.business_id, try_to_timestamp(e.checkin_ts, 'yyyy-MM-dd HH:mm:ss') AS checkin_timestamp, e._run_id
FROM workspace.yelp_silver._exploded_checkin e
JOIN workspace.yelp_silver.business_clean b ON b.business_id = e.business_id;

-- ---- Publication gate checks ----

-- Reconciliation is different in shape here (grain changed), so the check is
-- different too: total exploded timestamps should equal the sum of comma-separated
-- values across all valid bronze rows, not a 1:1 row match.
SELECT count(*) FROM workspace.yelp_silver.checkin_clean;
SELECT sum(size(split(parsed.date, ','))) FROM workspace.yelp_silver._checked_checkin
WHERE NOT hit_reject_bad_json AND NOT hit_q1_missing_key;

SELECT count(*) FROM workspace.yelp_silver.checkin_quarantine;
SELECT count(DISTINCT business_id) FROM workspace.yelp_silver.checkin_clean;   -- how many distinct businesses have any checkin
