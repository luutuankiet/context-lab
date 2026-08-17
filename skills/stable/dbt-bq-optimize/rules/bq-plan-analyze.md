# bq-plan-analyze — turn a BigQuery job_id into a ranked, source-mapped cost breakdown

**Inputs:** a BigQuery `job_id` (from the leaderboard in SKILL.md, or from `INFORMATION_SCHEMA.JOBS`), and *optionally* the model's compiled SQL path.
**Output:** red-flag stages, slot_ms ranking, per-stage performance-insight tooltips, and (if compiled SQL is given) candidate source-line mappings for each hot stage.

All bash. Set `BQ_PROJECT` / `BQ_LOCATION` first (see SKILL.md setup).

## 1. Dump the plan

```bash
bq --project_id=$BQ_PROJECT --location=$BQ_LOCATION show --format=prettyjson \
   -j '<BQ_JOB_ID>' > /tmp/job.json     # ~1 MB JSON for a 150-stage plan
```

## 2. Header summary (is it slot-bound, byte-bound, or skewed?)

```bash
jq '{job_id: .id, state: .status.state,
     total_slot_ms: (.statistics.totalSlotMs|tonumber),
     total_bytes: (.statistics.totalBytesProcessed|tonumber),
     wall_sec: ((.statistics.endTime|tonumber) - (.statistics.startTime|tonumber))/1000,
     stages: (.statistics.query.queryPlan|length),
     statement: .statistics.query.statementType,
     destination: .configuration.query.destinationTable}' /tmp/job.json
```

Avg parallelism ≈ `total_slot_ms / 1000 / wall_sec`. If that's high (hundreds) you are NOT slot-starved — the cost is real compute. If `total_slot_ms` dwarfs `wall_sec * peak_slots`, look for skew (step 5).

## 3. Top-N hot stages by slot_ms

```bash
jq '[.statistics.query.queryPlan[] | {
       id, name,
       slotMs: (.slotMs|tonumber),
       recordsRead: (.recordsRead // "0"|tonumber),
       recordsWritten: (.recordsWritten // "0"|tonumber),
       shuffleOutputBytes: (.shuffleOutputBytes // "0"|tonumber),
       computeMsMax: (.computeMsMax // "0"|tonumber),
       computeMsAvg: (.computeMsAvg // "0"|tonumber)
     }] | sort_by(-.slotMs) | .[0:10]' /tmp/job.json
```

The top 3 stages usually own the large majority of slot time. Read their `name` (`Join+`, `Sort+`, `Repartition`, `Aggregate+`) — that's the operation class to attack.

## 4. Record-explosion detector (finds fan-out joins)

A stage that reads N rows and writes ≫N is multiplying rows — a cross-product or range-join blow-up. This is the single most common dbt-model pathology.

```bash
jq '[.statistics.query.queryPlan[] | {
       id, name,
       recordsRead: (.recordsRead // "0"|tonumber),
       recordsWritten: (.recordsWritten // "0"|tonumber),
       slotMs: (.slotMs|tonumber),
       fanout: (if ((.recordsRead // "0"|tonumber) > 0)
                then ((.recordsWritten // "0"|tonumber) / (.recordsRead // "0"|tonumber))
                else null end)
     } | select(.fanout != null and .fanout > 5 and .recordsRead > 1000000)]
   | sort_by(-.fanout) | .[0:10]' /tmp/job.json
```

Invert the ratio (`recordsRead / recordsWritten > 5`) to find the **dedup-back-to-grain** stages that pay for the explosion downstream.

## 5. Skew detector (finds low-cardinality bucket keys)

One slot doing most of the work = a join/partition key with too few distinct values (or a hot value). `computeMsMax / computeMsAvg` ≫ 1 is the signal.

```bash
jq '[.statistics.query.queryPlan[] | {
       id, name,
       slotMs: (.slotMs|tonumber),
       computeMsMax: (.computeMsMax // "0"|tonumber),
       computeMsAvg: (.computeMsAvg // "1"|tonumber),
       parallelInputs: (.parallelInputs // "0"|tonumber)}
     | .skew = (if .computeMsAvg > 0 then (.computeMsMax / .computeMsAvg) else null end)
     | select(.skew != null and .skew > 3 and .slotMs > 1000000)]
   | sort_by(-.skew) | .[0:10]' /tmp/job.json
```

## 6. Performance-insight tooltips (BigQuery's own advice)

BigQuery attaches human-readable insights (high-cardinality joins, slot contention, partition-skew) to the job. They live in `INFORMATION_SCHEMA.JOBS`, not in `bq show`:

```bash
bq --project_id=$BQ_PROJECT --location=$BQ_LOCATION query --use_legacy_sql=false --format=prettyjson \
  "SELECT query_info.performance_insights
   FROM \`$BQ_PROJECT.region-eu.INFORMATION_SCHEMA.JOBS_BY_PROJECT\`
   WHERE job_id = '<BQ_JOB_ID>'"
```

`stage_performance_standalone_insights[]` carries `stage_id` + `slot_contention` / `insufficient_shuffle_quota` / `bi_engine_reasons`; `stage_performance_change_insights[]` carries `input_data_change`. Join these back to the plan by `stage_id`.

## 7. Merge insights into the ranked plan (jq by stage id)

Extract the plan once and the insights once, then merge so each hot stage shows its tooltip inline:

```bash
# plan stages → {id: slotMs}
jq '[.statistics.query.queryPlan[] | {key:.id, value:{name,slotMs:(.slotMs|tonumber)}}] | from_entries' /tmp/job.json > /tmp/stages.json
# then eyeball the top stage ids from step 3 against the performance_insights stage_id list from step 6.
```

Keep it simple: in practice you rank with step 3, then look up only the top 3–5 `stage_id`s in the step-6 output. No need to programmatically join all 150 stages.

## 8. Map a hot stage to source SQL

**Preferred — BigQuery Console, Query Visualization tab:** open the job, click a hot stage's substep; the source-text panel highlights the contributing SQL lines and the tooltip lists each stage's duration + slot-time. This is the documented, ground-truth mapping. Use it first.

**Fallback — compiled-SQL fingerprint (when no Console access):** if you bundled compiled SQL (`--model-path` on `dbtcx fetch-run`), match a stage to source by:
- **operator** in the stage `steps[]` (e.g. a `case_no_value(...)` COMPUTE carrying a CASE/classifier literal, or a `HASH JOIN EACH WITH ALL` broadcast) — grep that literal/predicate in the compiled SQL,
- **operand cardinality** (`recordsRead` vs `recordsWritten`) against the CTE you suspect,
- **position** in the step graph (which stage feeds which).

Inspect one stage's substeps in detail:

```bash
jq '.statistics.query.queryPlan[] | select(.id == "<STAGE_ID>")' /tmp/job.json
```

Note: the plan's `id` is the numeric stage id, NOT the hex display name (e.g. display `S6F` may be id `111`). Map via the `name` field or order.

Report per hot stage: `slot_ms`, fan-out / skew flag, BigQuery insight tooltip, and the candidate source CTE/line with a confidence note (Console-mapped = high; fingerprint = medium).
