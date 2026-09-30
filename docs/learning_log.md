# Learning log — Yelp secondary dataset

Same format as `D:\data-lab2\docs\learning_log.md`: dated entries, 2-3 lines per new
concept, written as things are actually learned, not planned in advance.

## Day (2026-09-29) — repo setup, Kaggle CLI

**Kaggle's API needs two separate approvals, not one.** Creating an API token in
account settings is not enough for a restricted-license dataset - you also have to
open the dataset's own page and click "I Understand and Accept" on its rules at least
once, or the CLI download fails even with a valid token.

**Kaggle CLI now supports a bare access-token file, not just the old `kaggle.json`
(username+key) format.** A file at `~/.kaggle/access_token` containing just the token
string authenticates the same way - simpler than the old two-field JSON credential.

## Day (2026-09-29/30) — business bronze + silver

**A search-result summary was wrong about the actual data shape, and only querying
real rows caught it.** Earlier research said `categories` was "a true array of
strings." The real bronze data shows it's a comma-separated STRING
(`"Food, Restaurants, Mexican"`), not a JSON array at all. Same lesson as the Dataplex
"free trial" mixup earlier in this project: a description of a dataset is not the
dataset - verify against real rows before designing rules around it.

**A JSON string value can itself contain broken, non-JSON syntax.** `attributes`'s
`BusinessParking` key holds a *string* like `"{'garage': False, 'street': False}"` -
Python dict repr (single quotes, capitalized booleans), not valid JSON, sitting inside
a JSON string value. Typing `attributes` as `MAP<STRING,STRING>` sidesteps this
cleanly: the outer map parses fine, and the broken inner value just stays an opaque
string until something actually needs to parse it further - deferred, not ignored.

**REJECT got used for real for the first time.** The BRFSS CSV pipeline never needed
a distinction between "quarantined" (readable, failed a rule) and "rejected"
(structurally unreadable) - `read_files` on a CSV either parses a row or the row
doesn't exist. JSON gives a real case: `from_json` returns NULL for the whole struct
when a line isn't valid JSON, genuinely different from a readable row that fails a
business rule. Same quarantine table, `severity='reject'` vs `'quarantine'` - exactly
what the brief's own quarantine table design already anticipated.

**Result: business.json is completely clean at the structural/key/range level.**
150,346 bronze rows -> 150,346 clean, 0 quarantined, 0 rejected, 0 duplicate keys.
The real messiness (the Python-repr-in-JSON-string problem) lives one level deeper
than any of silver's checks - inside individual `attributes` values - so it's
deferred to whichever gold table actually needs to parse `BusinessParking`, rather
than solved speculatively before anything needs it.

## Day (2026-09-30) — first gold table, real findings

**A business belonging to several categories at once needs `explode`, and the row
counts stop meaning "one row per business" once you do.** `gold.category_summary` has
1,311 rows summing to 668,592 business-count (average 4.45 categories per business,
150,346 real businesses) - correct, not a duplication bug, but a genuinely different
shape than every BRFSS gold table, where diabetes_code buckets were mutually
exclusive and counts summed back to the input exactly.

**Rating and survival (closure rate) are answering different questions, not the same
one.** Highest-rated categories (Real Estate Photography 4.91, niche personal
services) aren't the ones with the best survival - the highest closure rates
(Basque 64%, Bistros 61%, Moroccan 59%, French 54%) belong to well-liked niche
cuisines that are just hard to keep open. A high rating doesn't predict a business
staying open.

**Low-choice "necessity" services rate worst.** Television/Internet Service
Providers, Property Management, Apartments all sit at 2.0-2.6 stars - the pattern
looks like people rate things worse when they have no real alternative to switch to,
independent of actual service quality.

## Day (2026-09-30) — star schema vs. pre-aggregated gold tables

**Every BRFSS/Yelp gold table so far has been "pre-aggregated per question," not a
star schema.** A colleague built the same charts with far fewer tables using a proper
fact + dimension design. The difference: our way bakes the GROUP BY into the table
itself (new question = new table); fact/dim keeps one fine-grained fact table plus
small dimension tables, and every question is just a join + GROUP BY at query time
(new question = new query, not a new table). This is exactly the shape Power BI's own
DAX measures assume - it's *why* a semantic model exists.

**A many-to-many relationship (a business has several categories) needs its own
bridge table, not a column on the fact table.** Putting `category_id` directly on
`fact_business` would force duplicating every business row per category, which
corrupts any aggregate that isn't category-scoped (a plain `COUNT(*)` of businesses
would overcount). `bridge_business_category` keeps `fact_business` at exactly one row
per business while still representing the many-to-many.

**Not every attribute needs its own dimension table.** `city`/`state` stayed as flat
columns on `fact_business` (a "degenerate dimension") rather than a separate
`dim_geography` - a business has exactly one address, so a join would buy nothing.
Category needed a real dimension because of the many-to-many; geography didn't.

**Real syntax rule: `LATERAL VIEW` can't be directly followed by a plain `JOIN` in one
`FROM` clause.** Had to resolve the `explode()` in its own subquery first, then join
the result to `dim_category` - a genuine Spark SQL parser rule, not a style choice.

**Proved the two designs agree, not just assumed it.** Recomputed `category_summary`'s
own numbers (business_count, avg_stars, closed_rate_pct) via
`fact_business JOIN bridge_business_category JOIN dim_category`, diffed against the
stored table: 0 mismatches across all 1,311 categories.

**Retired `gold.category_summary` once the star schema was proven equivalent.** Table
DROPped in Databricks; the SQL file stays in git history with a "superseded" note at
the top rather than being deleted, same convention as BRFSS's old proof-of-concept
files. Any "rating/closure by category" question now goes through
`fact_business JOIN bridge_business_category JOIN dim_category` instead.

## Day (2026-09-30) — remaining 4 bronze tables loaded

**Caught myself inventing numbers before running anything, and fixed it before
running.** A draft of `06_bronze_remaining.sql` had "expected" row counts for
checkin/tip/user typed into a comment - made up, not sourced from anywhere. Fixed
before executing: replaced with an honest "NOT MEASURED yet" note. Real measured
counts, once actually run: checkin 131,930; tip 908,915; review 6,990,280 (matches
the dataset's own published "~6.99M" figure exactly); user 1,987,897. Full bronze
layer: ~10.17M rows across all 5 files.

## Day (2026-09-30) — silver for review, first real referential-integrity check

**A real foreign-key check, enforced for the first time in this project.** Every
review has a `business_id`; silver now checks it actually exists in
`business_clean` via a LEFT JOIN anti-join (not `NOT IN`, which doesn't scale the
same way against 150K businesses), flagging rule `FK1` on any orphaned review. The
brief's own "Referential integrity failure" quarantine category has been discussed
since early in this project but never actually implemented as its own rule until now.

**Result at real scale (6.99M rows): perfect.** 6,990,280 clean + 0 quarantined +
0 rejected = 6,990,280 bronze rows, exact. Zero duplicate review_id. **Zero FK
violations** - every single review's business_id genuinely exists in business_clean.
Whole 4-stage build (staged/checked/keyed/fk_checked) plus publish ran in ~107s
total on the same small serverless warehouse used for everything else in this
project - real scale (46x business.json's row count) didn't need different
infrastructure, just more time.

## Day (2026-09-30) — fact_review extends the star schema, one real finding for free

**Extending a star schema is additive, not a redesign.** Adding `fact_review` (a new
grain, one row per review) didn't touch `fact_business`, `dim_category`, or the
bridge table at all - just a new fact that happens to share `business_id` with the
existing one. Re-verified 0 orphaned business_ids at this layer too, on top of
silver's own FK check - belt and suspenders, cheap to do since the join is small.

**A real, unplanned finding came straight out of the first join query.** Nightlife's
average rating peaked at 3.94 in 2020 (COVID year) - the highest of any year - despite
review *volume* actually dropping that year (104,666 vs 201,861 in 2019). Not
explained yet (fewer venues open and only the best survived to get reviewed? people
more grateful to go out at all during lockdowns?), but genuinely surfaced by the data,
not searched for - the same kind of finding the BRFSS risk-stacking table produced.

## Day (2026-09-30) — silver for user, same correction pattern generalizes again

**`elite` and `friends` are both comma-separated strings, same as `categories` was.**
Confirmed by looking at real rows first (now the third time this exact pattern has
shown up on this dataset). One real user: 10 years of elite status
(2007-2016) and 550 friends, all packed into two string fields. Empty string ("")
correctly becomes an empty array via `NULLIF`, not a 1-element array containing "".

**Result: perfect reconciliation again, fourth time in a row on this dataset.**
1,987,897 clean + 0 quarantined + 0 rejected = 1,987,897 bronze rows, exact. 0
duplicate user_id. Every one of business/review/user has now published with zero
quarantine or reject rows - the real messiness on this dataset lives inside field
*values* (Python-repr strings, inconsistent WiFi encoding), not in structural
validity, which is a genuinely different failure profile than BRFSS (where R1 BMI
range was a real, frequently-firing rule).
