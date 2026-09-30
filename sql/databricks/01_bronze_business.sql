-- Databricks Trial: bronze for Yelp business.json.
-- Same bronze philosophy as the sibling BRFSS/Free-Edition project: raw and untouched,
-- no parsing or typing here - that's silver's job, one step later. For a JSONL file
-- (one JSON object per line), "untouched" means keeping the whole line as one STRING
-- column, not parsing it into fields yet - the JSON equivalent of BRFSS bronze keeping
-- every CSV column as STRING instead of casting on the way in.

CREATE SCHEMA IF NOT EXISTS workspace.yelp_bronze;

DROP TABLE IF EXISTS workspace.yelp_bronze.business;

-- read_files(format => 'text') gives one row per line in a `value` STRING column,
-- plus _metadata.file_name for provenance (Databricks' built-in file metadata column -
-- same idea as BRFSS's _source_file).
CREATE TABLE workspace.yelp_bronze.business AS
SELECT
  value                        AS raw_json,
  _metadata.file_name          AS _source_file,
  current_timestamp()          AS _loaded_at,
  'yelp-bronze-20260929'       AS _run_id
FROM read_files(
  '/Volumes/workspace/yelp_bronze/landing/business.json',
  format => 'text'
);

-- Verification
SELECT count(*) FROM workspace.yelp_bronze.business;               -- expect 150346 (known business count)
SELECT raw_json FROM workspace.yelp_bronze.business LIMIT 1;       -- eyeball: is it a real, complete JSON object per line?
