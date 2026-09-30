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
