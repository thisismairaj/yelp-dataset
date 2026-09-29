# **Team Kickoff Brief — Public Data on Snowflake and Databricks**

Sep 22, 2026 · @Abdullah Waqar

## **Objective**

The team must be able to demonstrate one public dataset flowing from both Snowflake Marketplace and Databricks Marketplace, through a curated layer, into your own storage and analytics platform — with measured numbers for ingestion, performance, cost and quality at every stage.

The deliverable is not a proof of concept. It is a **reference implementation plus a decision document**: at the end, you should be able to answer which platform your product builds on, with evidence rather than opinion.

### **Definition of done**

* ☐ Same public dataset live on both platforms, curated identically  
* ☐ An external consumer (outside both platforms) successfully queries both  
* ☐ Ingestion, latency, cost and quality metrics captured for both, same measurement method  
* ☐ Schema drift detected automatically on at least one real upstream change  
* ☐ A dashboard showing usage and performance, not a screenshot  
* ☐ A written platform recommendation with the numbers behind it

## **Assumptions to confirm**

Change any of these and the plan shifts. Correct them before the team starts.

| Assumption | Taken as | If wrong |
| :---- | :---- | :---- |
| Sequencing | Phases run in order, each gated | Parallelising Phase 3 with Phase 2 breaks the comparison |
| Team | 2 senior engineers, full-time | Partial allocation stretches every phase proportionally |
| Accounts | Trial or existing accounts on both platforms, provisionable at the start | Procurement delay pushes everything; start it today |
| Budget | Compute budget exists and has a ceiling | Without a ceiling, Phase 1 cost guardrails become mandatory, not recommended |
| Background | Both comfortable with SQL and Python; neither is a platform specialist | A specialist on one side changes the track split below |
| Cloud | Single cloud provider for both platforms initially | Cross-cloud adds egress cost and extends Phase 4 |
| Dataset domain | Open choice, driven by your product direction | A fixed domain narrows Phase 2 selection work |

## **Team split**

Each engineer owns one platform end to end, so you get two genuine depth builds rather than two shallow ones. Shared work is done jointly and must produce identical artefacts on both sides, or the comparison is worthless.

&nbsp;

| Area | Engineer A — Snowflake | Engineer B — Databricks |
| :---- | :---- | :---- |
| Platform | Snowflake account, warehouses, Horizon Catalog | Databricks workspace, Unity Catalog, clusters |
| Ingestion | Marketplace listing mount, COPY INTO, Snowpipe | Marketplace listing, Delta Sharing mount, Auto Loader |
| Storage format | Native tables and Iceberg tables | Delta tables and Iceberg |
| Sharing out | Secure Data Sharing, reader account, Iceberg share | OpenSharing, open client share, volume share |
| Compute tuning | Warehouse sizing, auto-suspend, clustering keys | Cluster sizing, runtime pinning, OPTIMIZE and Z-order |
| Cost control | Resource monitors, credit tracking | Budget policies, cluster policies, DBU tracking |

**Jointly owned, non-negotiable:**

* The dataset selection, so both sides carry the same data  
* The schema contract, written once and implemented twice  
* Metric definitions and measurement method, agreed before any measuring  
* The external consumer test, run by whichever engineer did not build that side

**Rule:** neither engineer measures their own platform. A measures B's, B measures A's. This is the cheapest available defence against motivated reasoning in the final recommendation.

## **Phase plan**

No dates here by design — phases are gated, not scheduled. Each phase splits into research (R) then implementation (I), and the research gate must close before implementation opens. Research produces written decisions; implementation produces working systems. Building before the research gate closes is how teams discover in Phase 5 that a Phase 2 choice was wrong. The gate must pass on **both** platforms before the next phase starts, so the tracks stay in step and the comparison holds.

| Phase | Research gate (R) | Implementation gate (I) |
| :---- | :---- | :---- |
| 1 — Foundations | Cost model written, region decided, measurement method agreed | Both platforms provisioned, ceilings live, first query cost known |
| 2 — Ingestion | Datasets chosen and verified on both, licences read, domain profiles drafted | Same dataset landed on both, row counts reconcile exactly |
| 3 — Modelling | Schema contract written, both engineers agree it is implementable identically | Contract views live, registry catching all three drift types |
| 4 — Sharing out | Documented limitations known, predictions written before testing | External client reads from both; predictions compared to reality |
| 5 — Landing zone | Format and catalog decided with reasoning, cost model built | Both sources writing to own storage, third engine reading it |
| 6 — Analytics | Engine chosen, latency requirement stated in advance | Benchmark run three ways, dashboard live on real metrics |
| 7 — Comparison | — | Written recommendation, every metric filled in, no blanks |

**Rhythm:** one short plan session at the start of each phase, one demo at the end. The demo is a working thing on screen, not slides. A phase that cannot demo has not passed its gate, regardless of how much was built.

**Escalation rule:** any gate at risk gets raised as soon as it is known, not at the demo. A slipped gate is fine; a surprise slipped gate is not.

## **Phase 1 — Foundations**

The point of this phase is that nothing later surprises you on cost, and both environments are genuinely comparable. Teams that skip this phase pay for it later, at the worst possible moment.

### **R1 — Research**

Answers on paper, not settings in a console. Nothing gets set up until these are answered, because the answers change what you set up.

| Question | Output |
| :---- | :---- |
| What does each platform actually cost us, in real money, at the size we expect? | A one-page cost estimate per platform |
| Which region and cloud should both sit in? | The decision, with the reason |
| What size compute do we start with, and how do we make it switch off when idle? | A sizing recommendation per platform |
| What spending limits can we set, and can they actually block spend or only warn? | What each platform can enforce |
| How do we measure cost the same way on two different billing systems? | The agreed method, written down |

**Gate out of research:** the cost estimate exists, the region is decided, and both engineers agree how cost will be measured.

### **I1 — Implementation**

**Engineer A — Snowflake**

* ☐ Provision account in the agreed region  
* ☐ Create separate warehouses for ingestion and query, sized per the research  
* ☐ Set auto-suspend to 60 seconds on every warehouse  
* ☐ Configure resource monitors with a hard credit ceiling and an alert at 50%  
* ☐ Run a trivial query; record credits consumed and wall-clock time

**Engineer B — Databricks**

* ☐ Provision workspace in the same region and cloud  
* ☐ Enable Unity Catalog; create catalog and schema structure  
* ☐ Create an all-purpose cluster and a job cluster, runtime version pinned  
* ☐ Configure cluster policies capping node count and instance type  
* ☐ Set auto-termination to 15 minutes  
* ☐ Run a trivial query; record DBUs consumed and wall-clock time

**Joint**

* ☐ Stand up the shared metrics store, a table both sides write to  
* ☐ Set up version control for all SQL, notebooks and config  
* ☐ Validate the cost model against the actual first-query cost, and correct it

### **Phase 1 targets**

| Metric | Target |
| :---- | :---- |
| Time to first successful query, both platforms | Recorded, both |
| Cost ceiling configured | Both platforms, before any bulk load |
| Idle compute cost per day | Under a documented threshold you set |
| Unpinned runtime or warehouse config | Zero |

## **Phase 2 — Dataset selection and ingestion**

### **Choosing the dataset (joint, before anything else)**

Pick **three** datasets, not one, covering different structural shapes. This is what forces the team to meet the real problems rather than the easy one.

| Slot | Shape | Selection criteria | Example type |
| :---- | :---- | :---- | :---- |
| Primary | Structured, large, time-series | Over 100M rows, updates at a known cadence, available on both marketplaces | Economic or financial time series |
| Secondary | Semi-structured | Nested fields, variable schema between records | Filing metadata, event logs |
| Stretch | Unstructured | Requires an extraction step before query | Filing text, transcripts |

**Hard requirement:** the primary dataset must exist on both marketplaces, or be reachable from both. Without that, there is no comparison. Verify this before committing, not after.

### **R2 — Research**

Choosing the wrong datasets here wastes the phases that follow, so this is reading and deciding, not building.

| Question | Output |
| :---- | :---- |
| Which datasets are available on both platforms, in the domains we want? | A shortlist, availability actually verified |
| What shape is each one — tabular, nested, or files? | A note on what each will need to become usable |
| How often does each update, and how does it deliver updates? | Update cadence and method per dataset |
| What does each licence allow us to do with the data? | A short licence summary per dataset |
| What formats are they delivered in? | The format per dataset, and what we will convert it to |

**Gate:** datasets chosen, availability confirmed by looking rather than assuming, licences read.

### **I2 — Implementation**

**Each engineer, on their own platform**

* ☐ Bring in a tabular dataset and get it queryable  
* ☐ Bring in a nested or semi-structured dataset and flatten it into proper columns  
* ☐ Bring in a file-based dataset and extract something usable from it  
* ☐ Handle the format conversion each one needs on the way in  
* ☐ Describe each dataset properly: row counts, blanks, ranges, what the columns mean  
* ☐ Record how long each load took and roughly what it cost

**Joint**

* ☐ Compare the two descriptions; investigate anything that does not match  
* ☐ Write down the obvious problems found in each dataset, before trying to fix them

### **Phase 2 targets**

| Metric | Target |
| :---- | :---- |
| Row count parity between platforms | Exact match, zero tolerance |
| Null rate parity per column | Within 0.01% |
| Time from listing mount to first query | Recorded on both, no target — this is a finding |
| Ingestion cost per 100M rows | Recorded on both, compared |
| Datasets with licence terms documented | 3 of 3 |
| Profiling queries identical across platforms | Yes, or the comparison is void |

## **Worked example — two use cases, two categories**

Two concrete assignments, one per engineer, from different domains. They are deliberately different in shape so the shared pipeline gets stress-tested rather than tuned to one case. Both must produce the same curated contract, the same quality artefacts, and the same metrics.

### **Use case A — Engineer A, Snowflake, healthcare**

**Question the data must answer:** how does hospital quality performance vary by geography, and which regions are outliers once population is controlled for?

| Element | Value |
| :---- | :---- |
| Domain | Healthcare |
| Source type | CMS hospital quality and provider data, plus census population |
| Structural shape | Structured, wide, moderate row count, annual reporting periods |
| Entity ID | CCN for facilities, FIPS for geography |
| Vocabulary | Measure IDs, condition codes |
| Join required | Facility to geography to population |
| Expected quality problem | Small-cell suppression, facilities closing or merging between periods |

**What makes this hard, and why it was chosen:** facility identifiers are not stable across years. Hospitals merge, close, change ownership and change CCN. A naive year-over-year comparison silently compares different entity sets. Suppression on small facilities means the denominators are incomplete in a non-random way.

### **Use case B — Engineer B, Databricks, education**

**Question the data must answer:** how do institutional outcomes relate to cost and enrolment composition, and how has that shifted over time?

| Element | Value |
| :---- | :---- |
| Domain | Education |
| Source type | IPEDS institutional data, plus regional economic indicators |
| Structural shape | Structured with semi-structured survey components, long time series |
| Entity ID | IPEDS UnitID, OPEID |
| Vocabulary | CIP program codes |
| Join required | Institution to region to economic series |
| Expected quality problem | CIP code revisions between cycles, institutions merging, reporting-basis changes |

**What makes this hard, and why it was chosen:** the time series is long enough to cross at least one CIP code revision, which is exactly the methodology-break problem. Academic year versus calendar year alignment against the economic series is a real decision the team must make explicitly.

### **What the pair is designed to expose**

| Shared problem | Shows up in A as | Shows up in B as |
| :---- | :---- | :---- |
| Entity instability over time | Facility mergers and CCN changes | Institution mergers and UnitID changes |
| Vocabulary versioning | Measure definition changes | CIP code revisions |
| Suppression semantics | Small-cell blanking | Small-enrolment blanking |
| Time convention mismatch | Reporting period versus calendar year | Academic year versus calendar year |
| Geographic join | Facility to FIPS | Institution to region |

**The point:** both engineers hit the same five problems wearing different clothes. If the pipeline handles both without domain-specific code outside the profile, the abstraction is right. If either engineer has to fork the transformation logic, it is not, and that is a finding worth more than the use cases themselves.

### **Deliverable for each use case**

* ☐ Domain profile file, filled in and version controlled  
* ☐ Curated contract view answering the stated question  
* ☐ Entity crosswalk handling identity changes over time  
* ☐ Vocabulary version column and crosswalk where the series crosses a revision  
* ☐ Quality report with every exclusion accounted for  
* ☐ The question answered, as a query and a chart, with caveats stated

## **Phase 3 — Modelling layer**

This phase builds the curated layer that the issue register identifies as the single highest-leverage mitigation. It is the most important phase of the seven.

&nbsp;

### **R3 — Research**

This is where you decide what clean data looks like. Decide it before writing the code that produces it.

| Question | Output |
| :---- | :---- |
| What should the cleaned-up version of each dataset look like? | The agreed column names, types and units, written down |
| How do we tell apart a real zero, a missing value, and a value deliberately withheld? | A simple rule, with examples from the actual data |
| What kinds of bad data will we see, and which can be safely fixed automatically? | A list of fixable problems and a list of ones we will not guess at |
| How does each platform notice when the source changes shape? | What each can catch, and what we need to build ourselves |
| Which identifiers do we join on, and do they stay stable over time? | The join keys, and where they are known to change |

**Gate:** the target shape is written down, and both engineers agree they can produce it identically.

### **I3 — Implementation**

**Both engineers, in parallel**

* ☐ Build three layers: raw as delivered, checked, and cleaned  
* ☐ Put views on top so nobody queries the raw tables directly  
* ☐ Apply the cleanup rules: formatting, padding, trimming, type fixes  
* ☐ Send anything that cannot be safely fixed to quarantine, with a reason  
* ☐ Build something that compares the incoming schema against what you expect, and flags changes  
* ☐ Run a quality check on every load and store the results

**Prove it works**

* ☐ Change a column name in a test copy — your checker should catch it  
* ☐ Change a column's type — same  
* ☐ Remove a column — same  
* ☐ Confirm the views keep working through a rename, so users see nothing break

### **Phase 3 targets**

| Metric | Target |
| :---- | :---- |
| Drift scenarios detected | 3 of 3, both platforms |
| Drift correctly classified by severity | 3 of 3 |
| User-facing queries touching raw tables | Zero |
| Quality profile coverage | Every column of the primary dataset |
| Contract view absorbs upstream rename | Yes, with no consumer-side change |

### **Handling corrupt and invalid data**

The governing rule: **nothing is ever silently dropped, and nothing is ever silently fixed.** Every record that does not reach the final version has a row explaining why, and every corrected value retains its original.

A pipeline that quietly discards 3% of records produces numbers nobody can defend. A pipeline that quarantines 3% with reasons produces a finding.

#### **The four outcomes**

Every record lands in exactly one, and the counts must sum to the input count. If they do not, the pipeline has a bug.

| Outcome | Meaning | Reaches final version |
| :---- | :---- | :---- |
| Clean | Passed every rule | Yes, unmodified |
| Corrected | Failed a rule with a deterministic, documented fix | Yes, flagged, original retained |
| Quarantined | Failed a rule with no safe fix | No, held for review |
| Rejected | Structurally unreadable | No, logged only |

#### **What may be corrected automatically**

Correction is allowed only where the fix is deterministic and reversible. If a human would have to guess, it is a quarantine, not a correction.

| Defect | Correction | Why it is safe |
| :---- | :---- | :---- |
| Leading zeros stripped from ZIP or FIPS | Left-pad to fixed width | Only one possible original value |
| Whitespace, case inconsistency in codes | Trim and normalize case | No information lost |
| Known encoding artefacts | Map via a fixed table | Deterministic, table is version controlled |
| Date in a documented alternate format | Parse per the source's stated format | Unambiguous when format is declared |
| Deprecated code with an official successor | Map via published crosswalk, keep original | Authority published the mapping |

#### **What must be quarantined, never corrected**

| Defect | Why no automatic fix |
| :---- | :---- |
| Value outside plausible range | Could be a real outlier or a unit error; guessing destroys either |
| Code not in any vocabulary version | May be a new code your crosswalk lacks |
| Duplicate primary key with conflicting values | No basis to pick a winner |
| Referential integrity failure | The parent record may arrive later |
| Ambiguous date | Day-month versus month-day cannot be resolved from the value alone |
| Suppression marker in a numeric field | Must be preserved as suppressed, never imputed |

**Never impute a missing value to make a join work.** This is the single most common way a pipeline manufactures data that looks real.

#### **The quarantine table**

One table, same shape for every dataset and domain:

| Column | Holds |
| :---- | :---- |
| record\_id | Source identifier or a generated surrogate |
| dataset\_id | Which dataset and version |
| run\_id | Which pipeline run caught it |
| rule\_id | Which rule failed |
| severity | Correctable, quarantine, reject |
| raw\_payload | The record exactly as received |
| reason | Human-readable explanation |
| status | New, reviewed, released, permanently excluded |
| resolved\_by | Who reviewed it, if anyone |

Quarantine is a holding area, not a bin. Records can be released back into the final version once a rule is corrected or a crosswalk is extended, and that release is itself a versioned event.

#### **Producing the final version**

The final version is a **published, immutable, versioned dataset**, not the current state of a table.

* ☐ Assign a version identifier to every publication, never overwrite in place  
* ☐ Publish the reconciliation with the data: input count, clean, corrected, quarantined, rejected, output count  
* ☐ Refuse to publish if the counts do not sum, or if the quarantine rate exceeds the threshold for that dataset  
* ☐ Include the rule set version and vocabulary versions used, in the manifest  
* ☐ Retain the previous version, so a user can reproduce an older analysis  
* ☐ Record the source snapshot the version was built from

**Publication gate — all must pass:**

| Check | Threshold |
| :---- | :---- |
| Record counts reconcile | Exact, no tolerance |
| Quarantine rate | Under the dataset's documented threshold |
| Correction rate | Under threshold, and every correction type accounted for |
| Schema matches contract | Exact |
| Key uniqueness | No duplicates on declared primary key |
| Join cardinality assertions | All hold |
| Suppression markers preserved | Zero markers silently turned into nulls or zeroes |

A failed gate blocks publication and raises an exception. It does not publish with a warning, because warnings are not read.

#### **What users see**

Every published version carries a quality manifest, available before a user connects, not after they build on it:

* Version identifier and the source snapshot behind it  
* Record counts across all four outcomes  
* Null rate and distinct count per column  
* Known issues inherited from the source  
* Rule set and vocabulary versions applied  
* What changed from the previous version

## **Phase 4 — Sharing out**

This is where the platform difference becomes concrete rather than theoretical.

### **R4 — Research**

The limits are already written down by the vendors. Read them first, so building confirms what you expected instead of discovering it the hard way.

| Question | Output |
| :---- | :---- |
| How can each platform share data outward, and what are the known limits of each way? | A list of limits per method, from the vendor docs |
| Which method works for someone who has neither platform? | The recommended route per platform |
| What does a new user have to do to connect? | The expected steps, before we make anyone do them |
| Which tools can read each kind of share? | A short compatibility list |
| Where can values get mangled in transit? | The specific cases to test |

**Gate out of research:** both engineers can say what they expect to fail before trying it. Whether the docs turn out to be accurate is itself worth knowing.

### **I4 — Implementation**

**Engineer A — Snowflake**

* ☐ Create a share and listing from the curated layer  
* ☐ Provision a reader account; time the full consumer onboarding  
* ☐ Publish an Iceberg table share; test external engine catalog reach  
* ☐ Log every limitation hit, with the exact error, against the predicted list

**Engineer B — Databricks**

* ☐ Create an OpenSharing share from the curated layer  
* ☐ Test the open-client path with no Databricks licence  
* ☐ Test both access paths where available: pre-signed URL and directory-based  
* ☐ Log every limitation hit, with the exact error, against the predicted list

**Joint — the consumer test**

* ☐ Stand up an external client on neither platform, plain Python with pandas  
* ☐ Connect to both shares; time each, count the steps, count the failures  
* ☐ Run the adversarial type tests the research defined  
* ☐ Each engineer tests the side they did not build  
* ☐ Compare predicted limitations against actual; document where the docs were wrong

### **Phase 4 targets**

| Metric | Target |
| :---- | :---- |
| External client reads successfully | Both platforms |
| Consumer onboarding steps | Counted on both, compared |
| Time to first external query from zero | Under 60 minutes, both |
| Type fidelity failures | Zero, or documented with cause |
| Limitations encountered | Fully documented, both sides |

## **Phase 5 — Your own landing zone**

This is the pivot. Up to here the team has been a consumer of two vendors. From here, the vendors become **sources** and your platform becomes the destination.

### **The decision this phase forces**

Before building, the team must choose and justify the storage format for the landing zone. This is the most consequential technical decision in the whole programme, because it determines what engines can read your data for the next several years.

| Option | Argues for | Argues against |
| :---- | :---- | :---- |
| Iceberg on object storage | Both vendors read and write it; broadest engine support; catalog choice stays open | More moving parts; catalog must be run or bought |
| Delta on object storage | Strong Databricks path; Snowflake reads it via external catalog | Write path from Snowflake is narrower |
| Parquet files, no table format | Simplest; universally readable | No ACID, no time travel, no schema evolution; you rebuild these yourself |
| Vendor-native tables | Best performance inside that vendor | Lock-in, which is exactly what this phase exists to avoid |

**Recommendation to test, not assume:** Iceberg on your own object storage with an independent catalog. It is the only option where neither vendor is privileged, and both platforms now read and write it. The team should prove this works both directions before committing.

### **R5 — Research**

This is the move into your own storage. The format choice here is hard to undo later, so decide it here rather than during the build.

| Question | Output |
| :---- | :---- |
| What format do we store data in, so both platforms and outside tools can read it? | The format choice, with the reasoning written down |
| How do we keep track of what tables exist and where? | The catalog approach |
| How do we lay out the data so common queries stay fast? | A simple partitioning plan based on how people actually query |
| How do we send only what changed, instead of reloading everything? | The update approach per source |
| What will storage actually cost us at our expected size? | A rough cost estimate to compare against staying on the vendors |

**Gate:** the format and layout decisions are written down before anything is provisioned.

### **I5 — Implementation: moving the data across**

* ☐ Set up storage in your own cloud account  
* ☐ Set up the catalog so tables are discoverable  
* ☐ Apply the agreed layout and naming  
* ☐ Move data from the Snowflake side into your storage; time it and record the cost  
* ☐ Move data from the Databricks side into the same storage; same measurements  
* ☐ Make sure both arrive in the same shape, so they are interchangeable afterwards  
* ☐ Check the moved data matches the source, row for row  
* ☐ Read it back with a tool that is neither Snowflake nor Databricks, to prove you are not locked in

### **I5 — Implementation: keeping it up to date**

* ☐ Build the regular load that brings in new data on a schedule  
* ☐ Send only what changed where the source supports it, rather than full reloads  
* ☐ Handle records that were updated at source, not just new ones  
* ☐ Handle corrections, where the source revises something it published earlier  
* ☐ Make the load safe to re-run: running it twice should not duplicate anything  
* ☐ Keep previous versions, so an old result can still be reproduced  
* ☐ Alert someone when a load fails or brings in far fewer rows than expected

### **I5 — Implementation: housekeeping**

* ☐ Schedule a cleanup job to merge small files, which are now your problem  
* ☐ Decide how long you keep old versions, and apply it  
* ☐ Test that you can actually restore from a backup  
* ☐ Set up who can access what  
* ☐ Track storage cost per dataset against the estimate from research

### **Phase 5 targets**

| Metric | Target |
| :---- | :---- |
| Both vendor sources writing to landing zone | Yes, both directions proven |
| Third-engine read from landing zone | Successful, no vendor runtime involved |
| Schema conformance across sources | Identical, verified by test |
| Incremental sync working | Yes, full reloads eliminated |
| Sync lag from source to landing zone | Under 24 hours |
| Storage cost per TB per month | Recorded, compared against vendor storage |
| Data reconciliation, vendor versus landing zone | Row-exact |
| Small file count per partition | Under a threshold you set and monitor |

## **Phase 6 — Analytics on your platform**

Everything so far produces data. This phase produces evidence, and it runs against your landing zone rather than either vendor — that is the point. The dashboard must run on real captured metrics from the shared metrics store, never mock numbers.

### **R6 — Research**

| Question | Owner | Output |
| :---- | :---- | :---- |
| Which query engine serves our landing zone best, and what does each cost to run? | Joint | Engine comparison with a recommendation |
| What query patterns does the product need, and which are expensive? | Joint | The patterns, drawn from Phase 2 profiling and the use cases |
| Where does caching help, and what invalidates each cached item? | Joint | Caching design with invalidation rules stated |
| How should the semantic layer be expressed so metric logic is defined once? | Joint | Semantic layer design |
| What latency does the product actually require, as opposed to what would be nice? | Joint | A stated requirement to measure against |

**Gate out of research:** the engine is chosen with reasoning, and the latency requirement is written down before anything is measured against it. Deciding what counts as acceptable after seeing the results is not a benchmark.

### **Query benchmark suite (joint, built first)**

Ten queries, written once, run identically in three places: Snowflake, Databricks, and your own landing zone through an independent engine. The third run is what tells you what performance costs when you leave the vendor.

| Query type | What it tests |
| :---- | :---- |
| Point lookup on indexed key | Best-case latency |
| Full-table aggregate | Scan throughput |
| Date-range filter, narrow | Partition pruning effectiveness |
| Date-range filter, wide | Degradation curve |
| Two-table join on clean key | Join performance |
| Two-table join via crosswalk | Real-world join cost |
| Nested field extraction | Semi-structured handling |
| Window function over time series | Analytical workload |
| Concurrent execution, 10 parallel | Contention behaviour |
| Cold start after idle | Warm-up cost, a real user experience |

Run each five times. Report median and p95, not the best run.

### **I6 — Implementation: dashboard**

* ☐ Ingestion: rows loaded per run, load duration, failure count, freshness lag in hours  
* ☐ Performance: median and p95 latency per query type, per platform, side by side  
* ☐ Cost: cost per query type, cost per TB scanned, idle cost per day, both platforms in one currency  
* ☐ Quality: null rate trend per column over time, drift events detected, records failing validation  
* ☐ Usage: queries per user, most-queried tables, bytes scanned per user, concurrency peaks

### **Charts that must exist**

* ☐ Latency comparison: grouped bars, query type on x-axis, one bar per platform  
* ☐ Cost per query type: same shape, cost on y-axis  
* ☐ Freshness lag over time: line per dataset  
* ☐ Concurrency versus latency: line showing where each platform degrades  
* ☐ Quality trend: null rate per key column across the whole programme

### **Phase 5 targets**

| Metric | Target |
| :---- | :---- |
| Benchmark queries run on both | 10 of 10, five runs each |
| Dashboard data source | Live metrics store, zero mock values |
| Metrics captured per platform | Ingestion, performance, cost, quality, usage — all five |
| Median latency, point lookup | Under 2 seconds, both platforms |
| p95 latency, wide range scan | Recorded and explained, no fixed target |
| Cost per TB scanned | Recorded on both, compared in one currency |
| Concurrency at which latency doubles | Identified on both |

### **I6 — Implementation: analytics capability**

The benchmark proves the data is reachable. This proves it is usable for what your product actually does.

* ☐ Choose and stand up the query engine for your landing zone; justify the choice against the alternatives  
* ☐ Implement the semantic layer: the metrics and dimensions your product exposes, defined once  
* ☐ Build aggregate and rollup tables for the query patterns the benchmark showed to be expensive  
* ☐ Implement caching where the access pattern justifies it, with a documented invalidation rule  
* ☐ Expose one working API or query endpoint against your own storage, not a vendor  
* ☐ Run the full quality and drift checks against the landing zone, independent of vendor tooling

| Metric | Target |
| :---- | :---- |
| Benchmark run on landing zone via independent engine | 10 of 10 |
| Latency penalty versus vendor-native | Measured and explained, not assumed acceptable |
| Semantic layer definitions | Single source, no duplicated metric logic |
| Product endpoint serving from own storage | Working, with latency recorded |
| Vendor runtime required at query time | None |

## **Metric definitions**

Agree these during Phase 1\. A metric measured two different ways on two platforms is not a comparison.

### **Ingestion**

| Metric | Definition | Target |
| :---- | :---- | :---- |
| Rows ingested per run | Count landed in raw layer | Matches source exactly |
| Ingestion duration | Wall clock, start of load to queryable | Recorded, compared |
| Ingestion cost per 100M rows | Platform cost units converted to currency | Recorded, compared |
| Freshness lag | Hours between source publication and availability | Under 24 hours |
| Failed loads | Count per week | Zero after Phase 2 |

### **Performance**

| Metric | Definition | Target |
| :---- | :---- | :---- |
| Median latency | 50th percentile over 5 runs, per query type | Recorded per type |
| p95 latency | 95th percentile, same runs | Recorded per type |
| Bytes scanned | Per query, from platform telemetry | Minimized through partitioning |
| Partition pruning ratio | Bytes scanned divided by total bytes | Under 10% on narrow date filters |
| Cold start penalty | First query after idle minus warm median | Recorded, both |

### **Cost**

| Metric | Definition | Target |
| :---- | :---- | :---- |
| Cost per TB scanned | Total cost divided by bytes scanned, one currency | Recorded, compared |
| Idle cost per day | Cost with zero queries run | Near zero after Phase 1 |
| Cost per benchmark suite run | Full 10-query suite, one pass | Recorded, compared |
| Budget consumed | Percentage of ceiling, checked each phase | Under 80% at programme close |

### **Quality**

| Metric | Definition | Target |
| :---- | :---- | :---- |
| Schema drift events detected | Count, by severity class | 100% of injected tests caught |
| Null rate per key column | Percentage, tracked weekly | Trend stable or explained |
| Row count parity across platforms | Absolute difference | Zero |
| Validation failures | Records failing contract per run | Under 0.1%, investigated above that |
| Join cardinality violations | One-to-one joins returning many | Zero, hard fail |

### **Usage**

| Metric | Definition | Target |
| :---- | :---- | :---- |
| Queries per consumer | Count, weekly | Baselined by Phase 6 |
| Bytes scanned per consumer | Sum, weekly | Baselined, used for cost attribution |
| Most-queried tables | Ranked | Drives partitioning priorities |
| Peak concurrency | Max simultaneous queries | Recorded, tied to degradation point |
| External consumer onboarding time | Zero to first query | Under 60 minutes |

## **Risks, mapped to phases**

Each risk below is drawn from the issue register. The phase column is where it will first appear if it is going to.

| Risk | Surfaces in | Early warning | Response |
| :---- | :---- | :---- | :---- |
| Primary dataset not on both marketplaces | Phase 2, day 1 | Verification step fails | Reselect immediately; do not proceed with a substitute on one side |
| Row counts will not reconcile | Phase 2 gate | Profile mismatch | Treat as a finding, not a blocker; explain before Phase 3 |
| Iceberg share unreachable by external catalog | Phase 4 | Consumer test fails on Snowflake side | Documented limitation; fall back to reader account, record the cost |
| Client version mismatch on open share | Phase 4 | External Python client errors | Pin client versions; document the working matrix |
| Type fidelity loss | Phase 4 adversarial tests | Decimal or timestamp values differ | Hard stop; this invalidates downstream numbers |
| Compute cost overrun | Phase 2 onward | Budget check above 80% | Ceilings from Phase 1 should prevent it; if not, Phase 1 was skipped |
| Unstructured stretch goal consumes the sprint | Phase 2 | Secondary dataset slipping | Drop the stretch dataset; it is explicitly optional |
| Engineers drift out of step | Any gate | One track demoing, one not | Gates exist for this; hold the faster track |

## **Final deliverables**

Due at the close of Phase 7\.

* ☐ Working reference implementation on both platforms, in version control  
* ☐ Curated contract layer with schema registry, both platforms  
* ☐ External consumer connection working on both, with documented onboarding steps  
* ☐ Landing zone in your own cloud storage, written to from both vendors, read by a third engine  
* ☐ Unified schema across both sources, with incremental sync running  
* ☐ Analytics and semantic layer running on your storage, with a working product endpoint  
* ☐ Live dashboard on real metrics across ingestion, performance, cost, quality, usage  
* ☐ Benchmark results: 10 queries, 5 runs, three execution targets, median and p95  
* ☐ Limitations log: every error hit, with cause and workaround  
* ☐ Platform recommendation, 2 pages maximum, every claim tied to a captured number  
* ☐ Runbook: how to add the next dataset without repeating Phase 1

### **What makes this succeed or fail**

Two failure modes. The first is two engineers building two impressive but non-comparable systems. Everything in the joint column exists to prevent that. If the schema contract, the metric definitions and the benchmark suite are not written jointly and first, the final recommendation will be opinion with numbers attached to it.

The second is subtler and matters more given where this is heading: building so deeply into one vendor's tooling that Phase 5 becomes a rewrite rather than a write-out. Every curated-layer decision in Phase 3 should be made with the landing zone in mind. If a transformation can only exist inside a vendor's engine, it belongs in the landing zone's pipeline instead.

### **Where this leads after Phase 7**

The architecture this programme produces treats Snowflake and Databricks as interchangeable sources feeding your own storage. That has three consequences worth deciding on deliberately once the numbers are in.

| Question | Why it becomes answerable |
| :---- | :---- |
| Do you keep both vendors, or drop one? | Phase 7 gives you the cost and capability numbers to decide |
| Does the vendor stay in the query path at all? | Phase 6 measures what leaving costs in latency |
| What does adding dataset four cost? | The runbook makes this a known number rather than a guess |

Related: the issue register covering what goes wrong with these datasets sits in a separate doc, and Phase 3 implements its central recommendation directly.