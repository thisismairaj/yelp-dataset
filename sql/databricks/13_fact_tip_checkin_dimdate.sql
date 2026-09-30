-- Databricks Trial: fact_tip, fact_checkin, and dim_date - finishing the star schema's
-- fact layer plus the shared date dimension every fact table can join against.

CREATE OR REPLACE TABLE workspace.yelp_gold.fact_tip AS
SELECT user_id, business_id, text, tip_date, compliment_count
FROM workspace.yelp_silver.tip_clean;

CREATE OR REPLACE TABLE workspace.yelp_gold.fact_checkin AS
SELECT business_id, checkin_timestamp
FROM workspace.yelp_silver.checkin_clean;

-- dim_date: one row per calendar day, spanning the REAL min/max dates found across
-- fact_review/fact_tip/fact_checkin (not a guessed range - least()/greatest() over 6
-- real MIN/MAX aggregate scans). Standard BI-ready shape: every fact table can join
-- this on its own date column for consistent year/month/day-of-week/quarter slicing,
-- instead of calling year()/month() ad hoc and differently in every query. Also the
-- exact shape Power BI wants for a proper "Date table" with time-intelligence DAX,
-- same lesson from the BRFSS dashboard's semantic model.
CREATE OR REPLACE TABLE workspace.yelp_gold.dim_date AS
SELECT
  d AS full_date,
  year(d)                    AS year,
  month(d)                   AS month,
  day(d)                     AS day,
  dayofweek(d)                AS day_of_week_num,
  date_format(d, 'EEEE')      AS day_name,
  date_format(d, 'MMMM')      AS month_name,
  quarter(d)                  AS quarter,
  (dayofweek(d) IN (1, 7))    AS is_weekend
FROM (
  SELECT explode(sequence(
    least(
      (SELECT min(date(review_date)) FROM workspace.yelp_gold.fact_review),
      (SELECT min(date(tip_date)) FROM workspace.yelp_gold.fact_tip),
      (SELECT min(date(checkin_timestamp)) FROM workspace.yelp_gold.fact_checkin)
    ),
    greatest(
      (SELECT max(date(review_date)) FROM workspace.yelp_gold.fact_review),
      (SELECT max(date(tip_date)) FROM workspace.yelp_gold.fact_tip),
      (SELECT max(date(checkin_timestamp)) FROM workspace.yelp_gold.fact_checkin)
    ),
    interval 1 day
  )) AS d
);

-- ---- Verification ----

SELECT count(*) FROM workspace.yelp_gold.fact_tip;       -- expect 908915
SELECT count(*) FROM workspace.yelp_gold.fact_checkin;   -- expect 13356875

SELECT count(*) FROM workspace.yelp_gold.dim_date;                    -- how many calendar days it actually spans
SELECT min(full_date), max(full_date) FROM workspace.yelp_gold.dim_date;  -- the real range, not assumed

-- The payoff: checkin patterns by day of week, using dim_date's join instead of
-- calling dayofweek() inline - the same join every future time-based chart reuses.
SELECT dd.day_name, count(*) AS checkin_count
FROM workspace.yelp_gold.fact_checkin fc
JOIN workspace.yelp_gold.dim_date dd ON dd.full_date = date(fc.checkin_timestamp)
GROUP BY dd.day_name, dd.day_of_week_num
ORDER BY dd.day_of_week_num;
