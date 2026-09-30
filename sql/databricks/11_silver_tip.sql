-- Databricks Trial: silver for Yelp tip, built from workspace.yelp_bronze.tip.
-- Same shape as review's silver - flat fields (user_id, business_id, text, date,
-- compliment_count), confirmed by looking at real rows first. Same FK check against
-- business_clean as review had, plus a new one: user_id must also exist in user_clean
-- (the first two-sided FK check in this project - both sides now have a clean table
-- to check against).

CREATE SCHEMA IF NOT EXISTS workspace.yelp_silver;

CREATE OR REPLACE TABLE workspace.yelp_silver._staged_tip AS
SELECT
  raw_json, _source_file, _loaded_at, _run_id,
  from_json(raw_json,
    'STRUCT<user_id:STRING, business_id:STRING, text:STRING, date:STRING, compliment_count:BIGINT>'
  ) AS parsed
FROM workspace.yelp_bronze.tip;

CREATE OR REPLACE TABLE workspace.yelp_silver._checked_tip AS
SELECT *,
  (parsed IS NULL)                                                     AS hit_reject_bad_json,
  (parsed IS NOT NULL AND (parsed.user_id IS NULL OR parsed.business_id IS NULL)) AS hit_q1_missing_key,
  (parsed IS NOT NULL AND parsed.date IS NOT NULL
     AND try_to_timestamp(parsed.date, 'yyyy-MM-dd HH:mm:ss') IS NULL) AS hit_d3_bad_date
FROM workspace.yelp_silver._staged_tip;

-- No K1 here: tips have no natural primary key field of their own (no tip_id in the
-- source), so duplicate-key checking doesn't apply the way it did for business/review/
-- user, which all have a real ID column. Noted plainly, not silently skipped.
CREATE OR REPLACE TABLE workspace.yelp_silver._fk_checked_tip AS
SELECT t.*,
  (b.business_id IS NULL AND t.parsed IS NOT NULL) AS hit_fk_business,
  (u.user_id IS NULL AND t.parsed IS NOT NULL)     AS hit_fk_user
FROM workspace.yelp_silver._checked_tip t
LEFT JOIN workspace.yelp_silver.business_clean b ON b.business_id = t.parsed.business_id
LEFT JOIN workspace.yelp_silver.user_clean u ON u.user_id = t.parsed.user_id;

CREATE OR REPLACE TABLE workspace.yelp_silver.tip_quarantine AS
SELECT
  NULL AS record_id, 'yelp_tip' AS dataset_id, _run_id AS run_id,
  'REJECT_BAD_JSON' AS rule_id, 'reject' AS severity,
  raw_json AS raw_payload,
  'Line is not valid JSON - structurally unreadable' AS reason,
  'new' AS status, CAST(NULL AS STRING) AS resolved_by
FROM workspace.yelp_silver._fk_checked_tip
WHERE hit_reject_bad_json

UNION ALL

SELECT
  NULL AS record_id, 'yelp_tip' AS dataset_id, _run_id AS run_id,
  concat_ws(',',
    CASE WHEN hit_q1_missing_key THEN 'Q1' END,
    CASE WHEN hit_d3_bad_date THEN 'D3' END,
    CASE WHEN hit_fk_business THEN 'FK1' END,
    CASE WHEN hit_fk_user THEN 'FK2' END
  ) AS rule_id,
  'quarantine' AS severity,
  to_json(named_struct('user_id', parsed.user_id, 'business_id', parsed.business_id,
                        'date', parsed.date))                          AS raw_payload,
  'Failed one or more contract rules - see rule_id' AS reason,
  'new' AS status, CAST(NULL AS STRING) AS resolved_by
FROM workspace.yelp_silver._fk_checked_tip
WHERE NOT hit_reject_bad_json
  AND (hit_q1_missing_key OR hit_d3_bad_date OR hit_fk_business OR hit_fk_user);

CREATE OR REPLACE TABLE workspace.yelp_silver.tip_clean AS
SELECT
  parsed.user_id, parsed.business_id, parsed.text,
  try_to_timestamp(parsed.date, 'yyyy-MM-dd HH:mm:ss') AS tip_date,
  parsed.compliment_count, _run_id
FROM workspace.yelp_silver._fk_checked_tip
WHERE NOT (hit_reject_bad_json OR hit_q1_missing_key OR hit_d3_bad_date OR hit_fk_business OR hit_fk_user);

-- ---- Publication gate checks ----
SELECT
  (SELECT count(*) FROM workspace.yelp_silver.tip_clean) AS clean,
  (SELECT count(*) FROM workspace.yelp_silver.tip_quarantine WHERE severity = 'quarantine') AS quarantined,
  (SELECT count(*) FROM workspace.yelp_silver.tip_quarantine WHERE severity = 'reject') AS rejected,
  (SELECT count(*) FROM workspace.yelp_bronze.tip) AS bronze_rows;

SELECT rule_id, count(*) FROM workspace.yelp_silver.tip_quarantine
WHERE severity = 'quarantine' GROUP BY rule_id ORDER BY 2 DESC;
