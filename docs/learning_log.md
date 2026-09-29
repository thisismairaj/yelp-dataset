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
