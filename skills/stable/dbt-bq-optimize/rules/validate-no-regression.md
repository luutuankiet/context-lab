# validate-no-regression — prove a perf refactor kept the output identical

A performance refactor that changes a single output value is a bug. For cost/finance models, "identical" means **bit-perfect**, not "close". This is the discipline that lets you ship with confidence. All bash + `bq`.

## The trap: aggregate parity hides per-row drift

A per-key `SUM` can match to the penny while individual rows differ — floating-point non-associativity and multiset-ordering noise cancel in a SUM. So validate at multiple grains, from cheapest to strictest.

## Layer 0 — apples-to-apples dev build

Build the refactored model in dev but read every *unmodified* upstream from production state, so any diff is pure refactor effect (not stale dev data):

```bash
dbt run -s <model> --target dev --defer --state <prod-manifest-dir>/ --favor-state
```

`--favor-state` is non-negotiable on long-lived shared dev schemas: `--defer` alone prefers whatever a previous developer left in the dev schema, giving stale-upstream drift. `--favor-state` flips preference to prod state for any ref outside the run selector. (Pull the prod manifest with `uvx dbtcx fetch-run <prod_run_id>` and point `--state` at its `artifacts/run_<id>/` dir.)

Then pull the dev model's new BQ job and diff `slot_ms` / `wall` / `bytes` / `rows` against the baseline (this is the perf win), and run the parity layers below (this is the safety proof).

## Layer 1 — per-key SUM bit-perfect (the cost-sensitivity gate)

FULL OUTER JOIN dev vs prod, per business key, summing every monetary field. **No `ROUND`** when checking for zero — you want to see the FP noise floor.

```sql
WITH dev AS (
  SELECT <group_key>, COUNT(*) n, SUM(<money_field>) s
  FROM `<dev_project>.<dev_dataset>.<table>` GROUP BY <group_key>),
prod AS (
  SELECT <group_key>, COUNT(*) n, SUM(<money_field>) s
  FROM `<prod_project>.<prod_dataset>.<table>` GROUP BY <group_key>)
SELECT COALESCE(d.<group_key>, p.<group_key>) AS k,
       d.n AS dev_n, p.n AS prod_n,
       d.s - p.s AS net_delta_raw                       -- NO ROUND
FROM dev d FULL OUTER JOIN prod p USING (<group_key>)
ORDER BY ABS(IFNULL(d.s - p.s, 1e18)) DESC
```

Pass: `ABS(net_delta_raw)` below the FP noise floor (e.g. < 1e-5 per key) AND `dev_n = prod_n`. A real logic bug shows a *systematic*, large, single-direction delta — not symmetric last-bit noise.

## Layer 2 — exhaustive per-field audit (one scan, every column)

`COUNTIF(IS DISTINCT FROM)` per top-level field + `ARRAY_LENGTH` + `TO_JSON_STRING` per array, in a single FULL OUTER JOIN keyed on the row's unique key.

```sql
WITH dev AS (SELECT * FROM `<dev_table>`), prod AS (SELECT * FROM `<prod_table>`)
SELECT
  COUNT(*) AS total_paired,
  COUNTIF(d.<key> IS NULL) AS missing_in_dev,
  COUNTIF(p.<key> IS NULL) AS missing_in_prod,
  COUNTIF(d.<field> IS DISTINCT FROM p.<field>) AS <field>_drift,         -- repeat per scalar field
  COUNTIF(ARRAY_LENGTH(d.<arr>) IS DISTINCT FROM ARRAY_LENGTH(p.<arr>)) AS <arr>_len_drift,
  COUNTIF(TO_JSON_STRING(d.<arr>) IS DISTINCT FROM TO_JSON_STRING(p.<arr>)) AS <arr>_raw_drift
FROM dev d FULL OUTER JOIN prod p USING (<key>)
```

Interpretation: `len_drift = 0` AND `raw_drift = 0` → the array is bit-perfect. `len_drift = 0` but `raw_drift > 0` → same elements, different intra-array order → go to Layer 3.

## Layer 3 — canonical multiset (separate ordering noise from real diff)

If an array's raw content drifts but its length does not, sort each array by its element JSON before comparing. Equal after sort = a multiset-equivalent ordering artifact (safe); still different = a real element-level diff.

```sql
COUNTIF(
  (SELECT TO_JSON_STRING(ARRAY_AGG(s ORDER BY TO_JSON_STRING(s))) FROM UNNEST(d.<arr>) s)
  IS DISTINCT FROM
  (SELECT TO_JSON_STRING(ARRAY_AGG(s ORDER BY TO_JSON_STRING(s))) FROM UNNEST(p.<arr>) s)
) AS <arr>_canonical_drift
```

A frequent benign source: a downstream `STRING_AGG` / `ARRAY_AGG` without `ORDER BY` produces a different concatenation order when the refactor changes join order. Same items, different string — a pre-existing nondeterminism the refactor merely exposed, not a regression.

## Layer 4 — composite-key uniqueness (run BEFORE trusting Layer 2 counts)

Per-row diff counts assume the join key is unique. If it isn't, a FULL OUTER JOIN cross-pairs duplicates and inflates every drift count.

```sql
SELECT <k1>, <k2>, COUNT(*) dup
FROM `<table>` GROUP BY <k1>, <k2> HAVING dup > 1 ORDER BY dup DESC LIMIT 20
```

Any `dup > 1` → find a stricter key, or fall back to Layer 1 aggregates (invariant to symmetric duplication).

## Attribution — is residual drift the refactor, or upstream evolution?

If parity is non-zero, check whether an upstream rebuilt between when prod and dev were built. Real-world upstreams refresh continuously; a dim rebuilt in the gap will change LEFT-JOIN matches and look like "drift".

```sql
SELECT destination_table.dataset_id AS dataset,
       destination_table.table_id   AS table_id,
       TIMESTAMP_TRUNC(MAX(end_time), SECOND) AS last_end
FROM `<project>.region-eu.INFORMATION_SCHEMA.JOBS_BY_PROJECT`
WHERE creation_time BETWEEN TIMESTAMP('<dev_build_utc>') AND TIMESTAMP('<prod_build_utc>')
  AND destination_table.table_id IN (<upstream_table_names>)
  AND state = 'DONE'
GROUP BY 1, 2 ORDER BY last_end
```

**Natural control (zero extra cost):** if a fresh prod build lands *after* your dev build with **no** upstream rebuild in between, compare dev against that newer prod — both consumed identical upstream state, so any remaining diff is pure refactor effect.

## Optional — adversarial second opinion

For a high-stakes claim, hand a fresh agent (no prior context) the exact list of parity claims + the queries above and a small BQ budget, and ask it to *refute* them. Expect a few narrative hypotheses to fall even when the core "output is identical" conclusion survives — that's the point.
