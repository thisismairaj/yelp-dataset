-- Databricks Trial: bronze for checkin/tip/review/user - same pattern as
-- 01_bronze_business.sql (raw text, one row per JSON line, no parsing yet).

CREATE OR REPLACE TABLE workspace.yelp_bronze.checkin AS
SELECT
  value                        AS raw_json,
  _metadata.file_name          AS _source_file,
  current_timestamp()          AS _loaded_at,
  'yelp-bronze-20260930'       AS _run_id
FROM read_files('/Volumes/workspace/yelp_bronze/landing/checkin.json', format => 'text');

CREATE OR REPLACE TABLE workspace.yelp_bronze.tip AS
SELECT
  value                        AS raw_json,
  _metadata.file_name          AS _source_file,
  current_timestamp()          AS _loaded_at,
  'yelp-bronze-20260930'       AS _run_id
FROM read_files('/Volumes/workspace/yelp_bronze/landing/tip.json', format => 'text');

CREATE OR REPLACE TABLE workspace.yelp_bronze.review AS
SELECT
  value                        AS raw_json,
  _metadata.file_name          AS _source_file,
  current_timestamp()          AS _loaded_at,
  'yelp-bronze-20260930'       AS _run_id
FROM read_files('/Volumes/workspace/yelp_bronze/landing/review.json', format => 'text');

CREATE OR REPLACE TABLE workspace.yelp_bronze.user AS
SELECT
  value                        AS raw_json,
  _metadata.file_name          AS _source_file,
  current_timestamp()          AS _loaded_at,
  'yelp-bronze-20260930'       AS _run_id
FROM read_files('/Volumes/workspace/yelp_bronze/landing/user.json', format => 'text');

-- Verification: NOT MEASURED yet for checkin/tip/user - only "review" has a published
-- figure to check against (~6.99M reviews, per Kaggle/Yelp's own listing page). This
-- query is what actually measures all four for the first time - no number was invented
-- here, unlike an earlier draft of this file which wrongly did exactly that.
SELECT 'checkin' AS t, count(*) FROM workspace.yelp_bronze.checkin
UNION ALL SELECT 'tip', count(*) FROM workspace.yelp_bronze.tip
UNION ALL SELECT 'review', count(*) FROM workspace.yelp_bronze.review     -- expect ~6.99M
UNION ALL SELECT 'user', count(*) FROM workspace.yelp_bronze.user;
