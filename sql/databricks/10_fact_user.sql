-- Databricks Trial: fact_user, extending the star schema. One row per user - same
-- reasoning as fact_business: no separate dim_user needed, since nothing here is a
-- many-to-many relationship at the user level itself. elite_year_count and
-- friend_count are kept as simple measures (array sizes); the years and friend edges
-- THEMSELVES are the genuinely many-to-many parts, and would need their own bridge
-- tables (bridge_user_elite_year, bridge_user_friend) if a specific question needs
-- them - not built here since nothing has asked for that yet.

CREATE OR REPLACE TABLE workspace.yelp_gold.fact_user AS
SELECT
  user_id, name, review_count, yelping_since, useful, funny, cool,
  size(elite_array)   AS elite_year_count,
  (size(elite_array) > 0) AS is_elite_ever,
  size(friends_array) AS friend_count,
  fans, average_stars,
  compliment_hot, compliment_more, compliment_profile, compliment_cute,
  compliment_list, compliment_note, compliment_plain, compliment_cool,
  compliment_funny, compliment_writer, compliment_photos
FROM workspace.yelp_silver.user_clean;

-- ---- Verification ----

SELECT count(*) FROM workspace.yelp_gold.fact_user;   -- expect 1987897

-- A real question this enables: do elite users actually leave more useful reviews,
-- or just more reviews overall? (volume vs quality, similar spirit to the BRFSS
-- weighted-vs-unweighted distinction - a raw count can mislead on its own.)
SELECT is_elite_ever, count(*) AS user_count,
       round(avg(review_count), 1) AS avg_review_count,
       round(avg(useful), 1) AS avg_useful_votes_received,
       round(avg(average_stars), 2) AS avg_rating_given
FROM workspace.yelp_gold.fact_user
GROUP BY is_elite_ever;

-- Sizing check for the two possible future bridge tables - real numbers before
-- deciding whether either is worth building.
SELECT sum(elite_year_count) AS total_elite_user_year_pairs,
       sum(friend_count) AS total_friend_edges
FROM workspace.yelp_gold.fact_user;
