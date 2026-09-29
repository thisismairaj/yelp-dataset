# Project: Yelp Open Dataset — Secondary Dataset (Databricks + Snowflake brief)

## What this is
This is the **secondary dataset** for the same team brief being worked on in the
sibling repo `D:\data-lab2` (the BRFSS/diabetes project). The brief requires 3 datasets:
Primary (100M+ rows, structured, dual-marketplace), Secondary (semi-structured, nested
fields, variable schema between records — this repo), Stretch (unstructured, optional).
Full brief text: `docs/brief.md` (copied from the sibling repo).

Yelp was picked because it's genuinely nested (not a flattened CSV mirror): `attributes`
is a nested object whose own values are sometimes nested objects; `categories` is a real
array; `hours` is a nested object; and which keys exist inside `attributes` genuinely
varies business to business — real variable schema, not a stretch interpretation of it.

**License note:** Yelp Open Dataset is academic/research use only, not commercial. Fine
for this learning project; record this plainly, don't gloss over it.

## About me
- Senior backend engineer (Node.js, 7 years). New to data engineering.
- I know: Spark DataFrames, Delta Lake, MERGE, medallion (bronze/silver/gold),
  Unity Catalog basics, window functions, partitioning. Snowflake: concepts only.
- Already built a full medallion pipeline once (BRFSS project) — skip re-explaining
  concepts covered there (bronze/silver/quarantine, quarantine table shape, weighted
  vs unweighted stats, quarantine vs correction). DO explain what's NEW here: handling
  nested/semi-structured data specifically (flattening JSON, arrays, VARIANT types,
  schema drift inside a nested field rather than at the column level).

## How to teach me (always)
- Simple English, short sentences. A real-life example for every genuinely NEW concept
  (skip re-explaining things already covered in the BRFSS project).
- Explain EVERY line of code you write, what it does and why.
- One step at a time. After each step: tell me what to run, what I should see, and ask
  ONE short checkpoint question before moving on.
- When I hit an error, explain the cause first, then the fix.
- Keep a learning log in docs/learning_log.md: each new concept in 2-3 lines.

## Rules (non-negotiable — same as the sibling project)
- NEVER invent numbers. Row counts, timings, costs must come from real runs.
  If a number is not measured yet, write "NOT MEASURED".
- NEVER mark a task done without verifying it (show the query that proves it).
- Nothing is silently dropped: bad rows go to a quarantine table with a reason.
- No secrets in code. Use a .env file (git-ignored) for tokens and passwords.
  The Kaggle token lives at ~/.kaggle/access_token, outside this repo entirely.
- Commit to git after each working step, with a clear message.
- Start with a small sample of the data. Scale up only after the pipeline works.
- Before any action that costs trial credits (big loads, warehouses, clusters),
  tell me the expected cost and wait for my OK.
- If something can't be done in our time or on our accounts, say so plainly and
  record it in docs/scope_and_gaps.md. Don't fake it.

## What you cannot do
- You can't click inside the Databricks, Snowflake or Power BI interfaces.
  For UI steps, give me exact click-by-click instructions and wait for me.

## Target platform for this dataset
Databricks **Trial** workspace (`actual-trial-personal-email` profile) — same one
already used for the BRFSS 5-year Lakeflow build. Not Free Edition, not Snowflake yet
(may extend later, same as the BRFSS project's platform-parity work).
