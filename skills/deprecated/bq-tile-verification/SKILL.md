---
name: bq-tile-verification
description: Autonomous BQ verification of Tableau tile parity. Given a Tableau worksheet config (from TWB extraction) and the derived_table SQL (from contract appendix), constructs and runs BQ queries that reproduce the exact numbers Tableau shows. Outputs verified BQ queries as source-of-truth artifacts. Use BEFORE writing LookML to determine the correct measure type, grouping dimension, and filter logic. Spawn as subagent during Phase 1.25 of the migration pipeline.
argument-hint: "[tile-name] [contract-path]"
---

# BQ Tile Verification (Source-of-Truth Queries)

> **BQ is the autonomous verification oracle.** It answers "does our approach produce the same numbers as Tableau?" without needing a human to run Looker explores. Use this skill BEFORE writing LookML — not after.

## Why BQ-First

| Without BQ verification | With BQ verification |
|---|---|
| Write LookML → user tests in Looker → wrong numbers → debug → iterate 4+ turns | Run BQ queries → confirm exact aggregation → write correct LookML first time → user verifies once |
| Agent guesses COUNT vs COUNTD | BQ proves which one matches |
| Agent guesses grouping dimension | BQ tests all candidates, picks the match |
| User is a manual Looker API (slow, frustrating) | Agent is fully autonomous until final visual check |

**Lesson learned (WB1234567 LOG-001):** Skipping BQ verification cost 4 turns of back-and-forth debugging in Looker. TWB extraction told us WHAT Tableau does; BQ told us the numbers match. Both are needed.

---

## Prerequisites

| Input | Source | How to Get |
|-------|--------|------------|
| **Derived table SQL** | Contract Appendix | `grep -n "Appendix" <contract_path>` then read the SQL block |
| **TWB worksheet config** | TWB extraction (E5, E7, E9, E10) | From the extraction results or re-query TWB XML |
| **Tableau observed values** | Screenshot or user-provided | The numbers visible on the Tableau tile (approximate OK) |
| **BQ MCP tool** | Session MCP tools | `retrieve_tools("bigquery execute sql")` — use whatever BQ tool is available |

> **Token economy:** Do NOT read the entire contract. Grep for `Appendix` + `SQL` to find the derived table SQL section. Grep for `Section 4` to find tile definitions. Read only what you need.

---

## Core Workflow

```
1. EXTRACT tile config from TWB (what Tableau computes)
   ↓
2. CONSTRUCT BQ queries with all candidate aggregations
   ↓
3. RUN queries against BQ
   ↓
4. COMPARE results against Tableau observed values
   ↓
5. OUTPUT: the verified BQ query that matches Tableau = source of truth
```

---

## Step 1: Extract Tile Config

For each tile, determine from TWB extraction:

| Element | TWB Location | What to Extract |
|---------|-------------|----------------|
| **Measure formula** | E5 calc fields | `COUNTD(...)`, `COUNT(...)`, `SUM(...)`, `RUNNING_SUM(...)` |
| **Columns/Rows shelves** | Worksheet `.table.rows` / `.table.cols` | What's on x-axis, what's on y-axis |
| **Color mark** | Worksheet `.table.panes.pane[].encodings.color` | Stacking/grouping dimension |
| **Filters** | E10 worksheet filters | Which fields are filtered + values |
| **Table calc type** | Calc `<calculation>` element | Regular calc vs `usr:` (table calc) |

### TWB Formula → BQ Aggregation Mapping

| TWB Formula | BQ Equivalent | LookML Type | Trap |
|---|---|---|---|
| `COUNTD([field])` | `COUNT(DISTINCT field)` | `count_distinct` | — |
| `COUNT([field])` | `COUNT(field)` | `count` | **NOT the same as COUNTD** |
| `SUM([field])` | `SUM(field)` | `sum` | — |
| `AVG([field])` | `AVG(field)` | `average` | — |
| `MIN/MAX([field])` | `MIN/MAX(field)` | `min`/`max` | — |
| `COUNTD(IF cond THEN field)` | `COUNT(DISTINCT CASE WHEN cond THEN field END)` | `count_distinct` + `sql: CASE` | — |
| `COUNT(IF cond THEN field ELSE NULL END)` | `COUNT(CASE WHEN cond THEN field END)` | `count` + filter | Counts rows, not unique |
| `RUNNING_SUM(COUNT(...))` | Window: `SUM(COUNT(*)) OVER (ORDER BY ...)` | `count` + `running_total()` table calc | **COUNT not COUNTD — critical** |
| `RUNNING_SUM(COUNTD(...))` | Cannot do in single query — use subquery | `count_distinct` + `running_total()` | Running sum of COUNTD ≠ COUNTD of running set |
| `LOOKUP(agg, -1)` | `LAG(agg) OVER (ORDER BY ...)` | `offset(measure, -1)` table calc | — |

### The COUNT vs COUNTD Trap (WB1234567 Lesson)

With a composite PK like `(customer_id, region)`, a customer in 2 regions has 2 rows:
- `COUNT(customer_id)` = 2 (counts rows)
- `COUNT(DISTINCT customer_id)` = 1 (counts unique customers)

When the Color mark groups by a customer-level field (e.g., `first_order_region`), ALL rows for a customer land in one group. So COUNT inflates that group by the number of extra region rows. **This is invisible in Tableau's UI** — both show as "AGG(field)" on the shelf. Only the XML `<calculation formula=...>` reveals the truth.

**Decision tree:**
```
Can you read the TWB <calculation formula>?
├── Yes → Use the formula literally
│   ├── COUNT → type: count in LookML
│   └── COUNTD → type: count_distinct in LookML
└── No (obfuscated or table calc)
    └── Run BQ with BOTH COUNT and COUNTD
        ├── Compare per-group values against Tableau
        ├── If COUNT matches → type: count
        └── If COUNTD matches → type: count_distinct
```

---

## Step 2: Construct BQ Queries

### Getting the Derived Table SQL

```bash
# In the contract, find the Appendix with the SQL
grep -n "Appendix.*SQL\|Raw Custom SQL\|derived_table" <contract_path>
# Read the SQL block
read_files(<contract_path>, start_line=<N>, end_line=<M>)
```

Alternatively, read the base view LookML:
```bash
grep -n "derived_table\|sql:" <base_view_path>
# Extract the SQL between sql: and ;;
```

### Wrapping the SQL

The derived table SQL is a standalone SELECT (possibly with CTEs). Wrap it as a CTE:

```sql
WITH <original_cte_1> AS (...),
     <original_cte_2> AS (...),
     ...
     full_data AS (
       <original_final_SELECT>
     )
-- Your verification query here
SELECT ... FROM full_data WHERE ...
```

**Do NOT nest WITH clauses** — BQ doesn't support `WITH` inside `WITH`. Flatten all CTEs to the top level.

---

### V1: KPI Single Value

For tiles showing a single number (e.g., "# Total Active Users").

```sql
WITH full_data AS (<derived_table_sql>)
SELECT
  COUNT(*) as count_rows,
  COUNT(DISTINCT <id_field>) as countd_users,
  COUNT(DISTINCT CASE WHEN <active_condition> THEN <id_field> END) as countd_active
FROM full_data
WHERE <filter_conditions>
```

**Compare:** Pick whichever aggregation matches the Tableau value.

### V2: Grouped / Stacked Bar

For tiles with a Color/stacking dimension.

```sql
WITH full_data AS (<derived_table_sql>)
SELECT
  <candidate_group_dim> as group_dim,
  COUNT(*) as count_rows,
  COUNT(DISTINCT <id_field>) as countd_users
FROM full_data
WHERE <filter_conditions>
GROUP BY 1
ORDER BY 2 DESC
```

**Run with EACH candidate grouping dimension** (e.g., `region`, `first_order_region`, `customer_segment`). The one where per-group values match Tableau is the correct stacking dimension.

### V3: Time Series (Non-Accumulative)

For bar/line charts grouped by date period (New Users by Year, etc.).

```sql
WITH full_data AS (<derived_table_sql>)
SELECT
  <date_trunc_expression> as period,
  <group_dim>,
  COUNT(DISTINCT <id_field>) as measure_value
FROM full_data
WHERE <date_field> >= DATE('<start_date>')
  AND <date_field> < DATE('<end_date>')
GROUP BY 1, 2
ORDER BY 1, 2
```

### V4: Accumulative / Running Total

For tiles with `RUNNING_SUM`. **This is the most error-prone pattern.**

```sql
WITH full_data AS (<derived_table_sql>),
periodic AS (
  SELECT
    GREATEST(<date_trunc>, DATE('<start_date>')) as period,  -- bucket pre-start into start
    <group_dim>,
    COUNT(*) as count_rows,         -- candidate 1: COUNT
    COUNT(DISTINCT <id_field>) as countd_users  -- candidate 2: COUNTD
  FROM full_data
  WHERE <date_field> < DATE('<end_date>')  -- accumulative: no start filter
  GROUP BY 1, 2
)
SELECT
  period, group_dim,
  SUM(count_rows) OVER (PARTITION BY group_dim ORDER BY period) as cumulative_count,
  SUM(countd_users) OVER (PARTITION BY group_dim ORDER BY period) as cumulative_countd
FROM periodic
ORDER BY period, group_dim
```

**Key points:**
- `GREATEST(period, start_date)` buckets pre-start users into the first visible period
- Accumulative filter = `< end_date` only (no start date in WHERE)
- Compare `cumulative_count` vs `cumulative_countd` against Tableau's per-group-per-period values

### V5: Pivot / Cross-Tab / Heatmap

For grid tiles with two dimensions (rows × columns).

```sql
WITH full_data AS (<derived_table_sql>)
SELECT
  <row_dim>,
  <col_dim>,
  COUNT(DISTINCT <id_field>) as measure_value
FROM full_data
WHERE <filters>
GROUP BY 1, 2
ORDER BY 1, 2
```

### V6: Pie / Donut

Same as V2 (grouped) but add percent-of-total:

```sql
WITH full_data AS (<derived_table_sql>),
grouped AS (
  SELECT <group_dim>, COUNT(DISTINCT <id_field>) as val
  FROM full_data WHERE <filters>
  GROUP BY 1
)
SELECT *, SAFE_DIVIDE(val, SUM(val) OVER ()) as pct_total
FROM grouped
ORDER BY val DESC
```

### V7: Table Calc Emulation

When the tile uses Looker table calculations, verify the underlying data and then emulate:

| Looker Table Calc | BQ Window Equivalent |
|---|---|
| `running_total(measure)` | `SUM(measure) OVER (PARTITION BY group ORDER BY period)` |
| `offset(measure, -1)` | `LAG(measure) OVER (PARTITION BY group ORDER BY period)` |
| `percent_of_total(measure)` | `SAFE_DIVIDE(measure, SUM(measure) OVER ())` |
| `(curr - offset(curr,-1)) / offset(curr,-1)` | `SAFE_DIVIDE(measure - LAG(measure) OVER (...), LAG(measure) OVER (...))` |

---

## Step 3: Run and Compare

### Tolerance Thresholds

| Gap | Diagnosis | Action |
|-----|-----------|--------|
| **< 0.1%** | Data drift (Tableau extract vs live BQ) | ✅ Accept |
| **0.1% - 1%** | Likely data drift, possible minor filter diff | ⚠️ Verify filters match |
| **1% - 5%** | Wrong filter or date boundary | 🔴 Check filter logic |
| **5% - 15%** | Wrong grouping dimension or measure type | 🔴 Test alternative dimensions |
| **> 15%** | Fundamentally wrong query | 🔴 Re-examine TWB config |

### Pattern: Total Matches but Per-Group Differs

This specific pattern means the **stacking dimension** is wrong:
- Stacked total matches (e.g., 1,234k = 1,234k) ✅
- But per-group values are redistributed ❌

**Fix:** The correct total comes from SUM of per-group counts. If the total is right but distribution is wrong, you're using the wrong dimension for GROUP BY. Test all candidate dimensions.

### Pattern: COUNTD < Tableau Value

If your COUNTD is systematically lower than Tableau across all groups, and the gap is proportional to multi-key users:
- Tableau is using **COUNT (rows)** not COUNTD
- Check TWB `<calculation formula>` for confirmation
- Use `type: count` in LookML

---

## Step 4: Output — Source-of-Truth Artifacts

The output of this skill is **the verified BQ query itself**. This becomes a reusable artifact:

### Per-Tile Verification Report

```markdown
## Tile: [Tile Name]

**TWB config:**
- Measure: RUNNING_SUM(COUNT([customer_id])) (TWB line NNN)
- Color: [Group By calc] = first_order_region
- Filter: Date filter - Accumulative (table calc, post-computation)

**Verified BQ query:**
```sql
<the exact query that produces matching numbers>
```

**Comparison (BQ vs Tableau at [date range]):**
| Group | BQ | Tableau | Delta |
|-------|-----|---------|-------|

**LookML implications:**
- measure: type: count (NOT count_distinct)
- pivot: customers_group_by (first_order_region)
- filter: filter_accum_order_date (< end_date only)
```

These reports become input for the LookML build phase — the developer knows EXACTLY what measure type, dimension, and filter to use.

---

## Subagent Prompt Template

```
You are verifying BQ data parity for a Tableau-to-Looker migration tile.

## Task
Construct and run BQ queries that reproduce the numbers shown on the
Tableau "[TILE_NAME]" tile. Output the verified query as a source-of-truth artifact.

## Inputs
- Contract path: [CONTRACT_PATH]
- TWB formulas for this tile: [PASTE FROM EXTRACTION]
- Tableau observed values: [PASTE SCREENSHOT DATA OR VALUES]
- Date range: [START] to [END]
- Filter conditions: [FROM TWB EXTRACTION]

## Steps
1. Grep the contract for "Appendix" to find the derived_table SQL
2. Read the SQL (it may be in a code block under "Appendix A" or similar)
3. Wrap the SQL in a CTE and add verification SELECT
4. Run with ALL candidate aggregations (COUNT, COUNTD, SUM)
5. Run with ALL candidate grouping dimensions
6. Compare against Tableau observed values
7. Output: the EXACT query that matches + comparison table + LookML implications

## BQ Tool
Discover via: retrieve_tools("bigquery execute sql")
Schema: describe_tools(["<tool_name>"]) before calling

[INSERT MCP SANDBOX RULES FROM SESSION]
```

---

## Common Pitfalls

| Pitfall | Impact | Fix |
|---------|--------|-----|
| Nested WITH clauses | BQ syntax error | Flatten all CTEs to top level |
| COUNT vs COUNTD assumption | 5-15% gap per group | Always test both, let numbers decide |
| Forgetting accumulative = no start date | Running total starts too late | WHERE uses `< end_date` only |
| Comparing totals without per-group | Misses stacking dimension errors | Always compare per-group values |
| Using COUNTD for RUNNING_SUM base | Running sum of COUNTD ≠ cumulative COUNTD | See V4 pattern — test both approaches |
| Hardcoding date range | Brittle queries | Parameterize dates in the output query |
| Reading entire contract for SQL | Token waste | Grep for Appendix, read just the SQL block |
| Skipping the TWB formula check | Guessing measure type | Always extract the actual `<calculation formula>` from TWB XML first |

---

## Integration with Migration Pipeline

This skill runs as **Phase 1.25** between Build and Dashboard:

```
Phase 0:    EXTRACT (TWB)       → Gate 1: Review
Phase 0.5:  CONTRACT             → Gate 2: Approve
Phase 1:    BUILD (LookML)       → Gate 3: Compile
Phase 1.25: BQ VERIFY (this)     → Gate 3.5: Numbers match   ← AUTONOMOUS
Phase 1.5:  DASHBOARD            → Gate 4: Visual match (user — ONE round)
```

**Or even better — run BQ BEFORE build:**

```
Phase 0:    EXTRACT (TWB)        → Gate 1: Review
Phase 0.5:  CONTRACT              → Gate 2: Approve
Phase 0.75: BQ VERIFY (this)     → Gate 2.5: Numbers match   ← AUTONOMOUS
Phase 1:    BUILD (informed by BQ) → Gate 3: Compile
Phase 1.5:  DASHBOARD             → Gate 4: Visual match
```

Phase 0.75 means the LookML build is INFORMED by verified BQ queries. No guessing.
