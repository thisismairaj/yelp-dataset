-- Databricks Trial: silver for Yelp user, built from workspace.yelp_bronze.user.
-- Same 4-stage shape as business/review. Confirmed real fields by looking at a short
-- row first (same habit that already caught mistakes twice on this dataset): elite and
-- friends are both comma-separated STRINGs (can be empty ""), same correction pattern
-- as business.categories - not real JSON arrays despite holding list-like data.

CREATE SCHEMA IF NOT EXISTS workspace.yelp_silver;

CREATE OR REPLACE TABLE workspace.yelp_silver._staged_user AS
SELECT
  raw_json, _source_file, _loaded_at, _run_id,
  from_json(raw_json,
    'STRUCT<user_id:STRING, name:STRING, review_count:BIGINT, yelping_since:STRING, ' ||
    'useful:BIGINT, funny:BIGINT, cool:BIGINT, elite:STRING, friends:STRING, fans:BIGINT, ' ||
    'average_stars:DOUBLE, compliment_hot:BIGINT, compliment_more:BIGINT, ' ||
    'compliment_profile:BIGINT, compliment_cute:BIGINT, compliment_list:BIGINT, ' ||
    'compliment_note:BIGINT, compliment_plain:BIGINT, compliment_cool:BIGINT, ' ||
    'compliment_funny:BIGINT, compliment_writer:BIGINT, compliment_photos:BIGINT>'
  ) AS parsed
FROM workspace.yelp_bronze.user;

CREATE OR REPLACE TABLE workspace.yelp_silver._checked_user AS
SELECT *,
  (parsed IS NULL)                                                     AS hit_reject_bad_json,
  (parsed IS NOT NULL AND parsed.user_id IS NULL)                      AS hit_q1_missing_key,
  (parsed IS NOT NULL AND parsed.average_stars IS NOT NULL
     AND parsed.average_stars NOT BETWEEN 0 AND 5)                     AS hit_r1_avg_stars,
  (parsed IS NOT NULL AND parsed.yelping_since IS NOT NULL
     AND try_to_timestamp(parsed.yelping_since, 'yyyy-MM-dd HH:mm:ss') IS NULL) AS hit_d3_bad_date
FROM workspace.yelp_silver._staged_user;

CREATE OR REPLACE TABLE workspace.yelp_silver._keyed_user AS
SELECT *,
  (parsed IS NOT NULL AND parsed.user_id IS NOT NULL
     AND count(*) OVER (PARTITION BY parsed.user_id) > 1)              AS hit_k1_dup_pk
FROM workspace.yelp_silver._checked_user;

CREATE OR REPLACE TABLE workspace.yelp_silver.user_quarantine AS
SELECT
  NULL AS record_id, 'yelp_user' AS dataset_id, _run_id AS run_id,
  'REJECT_BAD_JSON' AS rule_id, 'reject' AS severity,
  raw_json AS raw_payload,
  'Line is not valid JSON - structurally unreadable' AS reason,
  'new' AS status, CAST(NULL AS STRING) AS resolved_by
FROM workspace.yelp_silver._keyed_user
WHERE hit_reject_bad_json

UNION ALL

SELECT
  parsed.user_id AS record_id, 'yelp_user' AS dataset_id, _run_id AS run_id,
  concat_ws(',',
    CASE WHEN hit_q1_missing_key THEN 'Q1' END,
    CASE WHEN hit_r1_avg_stars THEN 'R1' END,
    CASE WHEN hit_d3_bad_date THEN 'D3' END,
    CASE WHEN hit_k1_dup_pk THEN 'K1' END
  ) AS rule_id,
  'quarantine' AS severity,
  to_json(named_struct('user_id', parsed.user_id, 'average_stars', parsed.average_stars,
                        'yelping_since', parsed.yelping_since))        AS raw_payload,
  'Failed one or more contract rules - see rule_id' AS reason,
  'new' AS status, CAST(NULL AS STRING) AS resolved_by
FROM workspace.yelp_silver._keyed_user
WHERE NOT hit_reject_bad_json
  AND (hit_q1_missing_key OR hit_r1_avg_stars OR hit_d3_bad_date OR hit_k1_dup_pk);

-- Clean: elite/friends split into arrays (correction, raw kept alongside) - empty
-- string becomes an empty array via NULLIF, not a 1-element array of "".
CREATE OR REPLACE TABLE workspace.yelp_silver.user_clean AS
SELECT
  parsed.user_id, parsed.name, parsed.review_count,
  try_to_timestamp(parsed.yelping_since, 'yyyy-MM-dd HH:mm:ss') AS yelping_since,
  parsed.useful, parsed.funny, parsed.cool,
  parsed.elite AS elite_raw,
  CASE WHEN nullif(parsed.elite, '') IS NULL THEN array() ELSE split(parsed.elite, ',') END AS elite_array,
  parsed.friends AS friends_raw,
  CASE WHEN nullif(parsed.friends, '') IS NULL THEN array() ELSE transform(split(parsed.friends, ',\\s*'), x -> trim(x)) END AS friends_array,
  parsed.fans, parsed.average_stars,
  parsed.compliment_hot, parsed.compliment_more, parsed.compliment_profile,
  parsed.compliment_cute, parsed.compliment_list, parsed.compliment_note,
  parsed.compliment_plain, parsed.compliment_cool, parsed.compliment_funny,
  parsed.compliment_writer, parsed.compliment_photos,
  'C1_ELITE_FRIENDS_SPLIT' AS corrections,
  _run_id
FROM workspace.yelp_silver._keyed_user
WHERE NOT (hit_reject_bad_json OR hit_q1_missing_key OR hit_r1_avg_stars OR hit_d3_bad_date OR hit_k1_dup_pk);

-- ---- Publication gate checks ----

SELECT
  (SELECT count(*) FROM workspace.yelp_silver.user_clean) AS clean,
  (SELECT count(*) FROM workspace.yelp_silver.user_quarantine WHERE severity = 'quarantine') AS quarantined,
  (SELECT count(*) FROM workspace.yelp_silver.user_quarantine WHERE severity = 'reject') AS rejected,
  (SELECT count(*) FROM workspace.yelp_bronze.user) AS bronze_rows;

SELECT count(*) - count(DISTINCT user_id) FROM workspace.yelp_silver.user_clean;   -- expect 0

-- Eyeball the split
SELECT elite_raw, elite_array, size(friends_array) AS friend_count
FROM workspace.yelp_silver.user_clean
WHERE elite_raw != '' LIMIT 3;
