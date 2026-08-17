# Good PR Traits

write-pr does NOT prescribe a section outline. Pick the structure that fits the change — TL;DR-first / problem-first / validation-first / whatever.

**write-pr DOES prescribe traits.** A good PR has these traits regardless of which sections you chose. Read this file BEFORE writing the template; audit your draft against it BEFORE rendering.

## The 8 traits

### 1. Spoon-feed evidence inline

Every assertion is followed by the data that proves it, in the PR body. A reviewer should never open another tab to understand a claim. Evidence takes multiple forms — tabular data, code, SQL, AND **diagrams** (mermaid renders natively on GitHub; use it for topology, state machines, sequence flows, data lineage).

| Good | Bad |
|---|---|
| "p95: 1450ms → 55ms" + `[[ before \| delta_table(after) ]]` | "p95 dropped 50% (see BQ run `bquxjob_a1b2c3_demo`)" |
| SQL diff pasted in fenced block | "we changed the JOIN logic" |
| `code_expand` of the changed range | "see `models/foo.sql`" (no line, no content) |
| `[[ rows \| md_table ]]` for query results | "the validation returned 124,959 / 124,959" (no table) |
| Inline ```mermaid``` block for topology / state machine / sequence / data flow | "data flows from A → B → C" (described in prose, never drawn) |

Behavior: before finalizing each section, scan for two trigger classes:
- `"see X"` / `"check X"` / `"the result was Y"` — missing tabular / code / SQL evidence → paste it inline
- `"flows from"` / `"the topology"` / `"the sequence"` / `"the state machine"` / `"data lineage"` — missing diagram → add an inline mermaid block

**Mermaid note:** the `mermaid` filter was dropped in v0.2.0 (over-niche for disk-artifact use case — agents rarely have a `.mmd` file pre-authored on disk). Author mermaid blocks INLINE in the template; `snippets/mermaid_flowchart.j2` has a copy-paste skeleton with common shape patterns.

### 2. Resolve private context to plain english

Private context = anything only the author can see. Two forms — and `rules/private-notation.md` only catches the first:

| Form | Example | Fix |
|---|---|---|
| Symbolic (covered: `private-notation.md`) | `see LOG-007`, `per WORK.md`, `gsd-lite/...` | inline the evidence the token pointed at |
| Verbal (covered HERE) | "prior validation cycles drove drift to zero", "baseline failure rate", "as previously confirmed", "historically" | name the run (job ID + date + commit SHA) AND paste the result inline |

Behavior: workflow.md Step 4 catches symbolic form via regex. For verbal form, also scan `prior cycle|baseline|previously|earlier|historically|as established`. Each hit needs a reproducible anchor + inline result, or remove the claim.

### 3. Collapse at section boundary

GitHub PR viewer has no table of contents. A 1000-line PR is a wall of text on first paint. Fix: wrap section BODIES in `<details>`, leaving `##` headings visible at the section level — reviewer scans the heading outline, expands the bodies that matter.

**Correct shape:**

```markdown
## Root cause

<details><summary>Click to expand details</summary>

...body...

</details>
```

`Click to expand details` is the default summary text. Override with a more descriptive label when it earns its keep (e.g. `<summary>Exhaustive 56-field audit</summary>`).

| Pattern | Renders as |
|---|---|
| Heading visible at `##`, body wrapped in `<details>` with `Click to expand details` summary | Scannable section outline + explicit expand affordance per section |
| `<details><summary>## My Section</summary>...body...</details>` | **ANTIPATTERN** — heading becomes the click-target and disappears when collapsed; loses the GitHub anchor link; the expand affordance is invisible because the bold heading looks like an ordinary heading. Render-time lint hard-errors on this. |
| Bare `## My Section` + inner `fold` blocks only | Reviewer must scroll the whole PR linearly — fine for short PRs, breaks for >500 lines |

**Single-level rule (per user design: no nesting):** if you wrap a section's body in `<details>`, don't ALSO use `fold` (or `json_pretty(fold=true)`) on individual blocks inside that section. Pick ONE collapse layer.

Alternative pattern: leave `##` sections fully un-wrapped and use `fold` for individually-long inner blocks (see Trait 3a size heuristic). Works fine for short PRs (≤200 lines) where scannability isn't critical. For long PRs (>500 lines), section-body wrap is the only pattern that actually solves the wall-of-text problem.

`###` sub-sections always stay un-wrapped regardless of which pattern you chose.

Behavior: in the rendered output, any `<summary>` containing a `#` heading line is the antipattern — the render step lints for this and fails hard. See `rules/template-gotchas.md` Gotcha 3.

### 3a. Block-level collapse trigger (size heuristic)

Trait 3 is about section-boundary wrapping. This is its block-level corollary for individual evidence dumps that don't warrant a whole section but still outscroll their own context.

Cognitive ceiling, not browser-perf ceiling: a block bigger than ~one PR-pane scroll-height makes the reviewer lose orientation (the heading scrolls away before they finish reading the evidence). GitHub's renderer handles 500+ row tables fine; the binding constraint is human scannability.

Default thresholds — inline below, fold above:

| Block | Inline | Fold |
|---|---|---|
| `md_table` row count | ≤10 | >10 |
| `delta_table` row count | ≤10 | >10 |
| `json_pretty` line count | ≤15 | >15 |
| `code_expand` line count | ≤25 | >25 |

Compose with `fold`: `[[ rows | md_table | fold('Exhaustive 56-field audit') ]]`. Give the `<summary>` a descriptive label — "Details" is wasted real estate; the summary IS what the reviewer reads to decide whether to expand.

Override when the block IS the side-by-side comparison the reviewer needs at-a-glance — a 12-row before/after metric delta where every row matters can stay inline; a 5-row table that exists only to substantiate one already-stated number can fold.

Interaction with single-level rule: if the enclosing `##` section is already `<details>`-wrapped per Trait 3, drop the inner fold (no nesting). Pick the collapse layer that better serves scannability — section-wrap for long PRs (>500 lines), block-fold for short PRs.

### 4. Anchor prior-run claims to a reproducible ID

Every measured-data reference cites the exact run (BQ job ID, dbt run ID, commit SHA, CI URL) AND pastes the result inline. "Prior runs showed X" is invisible to the reviewer — name the run.

| Good | Bad |
|---|---|
| "30-run audit (job `bquxjob_d4e5f6_demo`, 2026-05-17): 7/30 errored" + `md_table` of the runs | "baseline failure rate is 23%" |
| "Pre-change p95: 1450ms (BQ job `abc-123`, 2026-05-12)" + stats json | "the query was slow before" |

Behavior: every numeric / quantitative claim traces back to a `queries/*.json` evidence file. If it doesn't, gather the evidence or drop the claim.

### 5. Text-fallback for auth-gated links

Links to GCP Console, dbt Cloud, internal dashboards, private Looker — anyone outside the org gets 401/403. The link can stay for convenience; the data behind it must ALSO be inline.

| Good | Bad |
|---|---|
| BQ console link + 4-row `md_table` of the stage breakdown | BQ console link alone ("see slot timeline at https://...") |
| dbt Cloud URL + `jq` command + the verbatim `run_results.json` snippet | "see https://gl652.us1.dbt.com/.../runs/.../" |

Behavior: after pasting any URL, ask "can a reviewer outside this org see what I see?" If no, add the text/table fallback inline before the link.

### 6. Tag hypothesis vs measurement

Words like "likely", "probably", "suggests", "appears" mark inferences, not measurements. Flag them so the reviewer doesn't conflate the two.

| Good | Bad |
|---|---|
| "**[hypothesis — not yet confirmed]** order_total drift likely due to currency-rate evolution. To confirm: `<query>` (not yet run)" | "the drift is likely due to currency-rate evolution" |
| "**[measured]** snp_product_costs WAS rebuilt in the window" + the query + the result row | "snp_product_costs evolved during the audit" |

Behavior: scan draft for `likely|probably|suggests|appears|expected|presumably`. Each hit: either add the confirming query + result inline, or prefix the sentence `[hypothesis - not yet confirmed]`.

### 7. File citations carry line ranges

Every file path in prose carries `:N` or `:N-M`. Bare `src/foo.sql` is one tab-open per citation; `src/foo.sql:42-58` is zero.

| Good | Bad |
|---|---|
| `models/foo.sql:160` | `models/foo.sql` |
| `models/foo.sql:120-185` + `code_expand` of that range | "the join logic in foo.sql" |
| New files: cite by CTE / function name + approx line in the new file | "added new model `int_product_costs_lookup.sql`" (no internal anchor) |

Behavior: grep your draft for `\.(sql|py|ts|tsx|yml|yaml)\b[^:]`. Each hit needs a line range. See `rules/root-path.md` for the `code_expand` mechanics that make this cheap.

### 8. Lead with narrative TL;DR, not the data table

A bare metrics table at the top of a non-trivial PR forces the reviewer to reconstruct the story from numbers. Open with a 4-paragraph executive narrative — problem → cause → fix → safety — THEN the data table. The numbers become confirmation of the story, not the story itself.

| Good | Bad |
|---|---|
| `**The problem**` paragraph naming the symptom + one concrete metric, then `**Why it was slow**`, `**The fix**`, `**Why it's safe**` — THEN the delta table | `## TL;DR` directly followed by a 6-row metrics table; reviewer has to reconstruct what happened from the numbers |
| Each paragraph 2-5 sentences; bolded label; one or two `**bolded**` headline numbers inside the prose | Multi-paragraph prose dump; numbers buried mid-sentence; no scannable bold-label structure |
| Paragraph 4 explicitly names what is NOT changed and what is out of scope | "Should be safe" without naming the semantic-preservation argument |

The 4-paragraph pattern:

| Paragraph | Bolded label (perf default) | Content |
|---|---|---|
| 1 | **The problem** | What was wrong; key user-visible symptom; one concrete headline number |
| 2 | **Why it was slow** | Root cause mechanism (planner behavior, race condition, schema mismatch, etc.); the specific bottleneck |
| 3 | **The fix** | What you did + the key insight; one or two performance / correctness numbers |
| 4 | **Why it's safe** | Semantic preservation argument; what is NOT changed; what is out of scope |

Label adapts to PR type — paragraphs 1 and 3 stay the same; 2 and 4 swap to fit the change:

| PR type | Paragraph 2 label | Paragraph 4 label |
|---|---|---|
| Perf refactor | "Why it was slow" | "Why it's safe" |
| Bug fix | "Why it broke" | "Why this won't regress" |
| Schema migration | "Why the old shape hurt" | "Why the migration is reversible" |
| Security fix | "How it was exploitable" | "What's still in scope to harden" |

Behavior: for any PR longer than ~200 lines OR involving a non-trivial mechanism (perf refactor, schema migration, bugfix with subtle correctness implications), draft the narrative section FIRST and let it set the section structure for the rest of the PR. The reviewer reads the 4 paragraphs (~30 seconds), decides whether they care, then expands the wrapped sections for evidence.

When to skip: trivial single-file fixes, dependency bumps, config tweaks — there is no "story" worth telling. A bare metrics table or a single short prose paragraph is sufficient.

The `snippets/narrative_tldr.j2` snippet provides this pattern as a parameterized include.

## Meta-trait: describe, don't template

These are the QUALITY BAR. They are NOT a section outline.

- Perf refactor → probably opens with a TL;DR metrics table
- Schema migration → probably opens with the upgrade path
- Bug fix → probably opens with the reproduction

What stays the same across all three: the 8 traits. Apply them to whatever structure fits.

The `snippets/` directory is a MENU of composable section patterns, not a required outline. Use 0, 1, or all 11 of them — your call. Just hit the 8 traits.

## Pre-render trait audit

After `npx -y @luutuankiet/write-pr render ...`, walk this audit (add to workflow.md Step 4):

```bash
# Trait 1: orphan "see X" pointers (review prompt, not hard gate)
rg -n '\bsee\b.*https?://|\bsee the\b' PR.md

# Trait 2 symbolic: private-notation (HARD GATE — zero expected)
rg -n '\bLOG-[0-9]|\bTASK-[0-9]|gsd-lite/|WORK\.md' PR.md

# Trait 2 verbal: prose forms of private-context leak
rg -in 'prior cycle|baseline|previously|earlier|historically|as established' PR.md
# Each hit: anchor to a reproducible ID OR remove

# Trait 3: top-level section wrap count
H2=$(rg -c '^## ' PR.md || echo 0)
WRAP=$(rg -c '<details><summary>## ' PR.md || echo 0)
echo "h2: $H2  |  wrapped: $WRAP  (expect WRAP >= H2 - 1; TL;DR can stay open)"

# Trait 6: hypothesis tags
rg -in '\b(likely|probably|suggests|appears|expected|presumably)\b' PR.md
# Each hit: must be tagged [hypothesis ...] OR have inline confirming query

# Trait 7: file paths missing line range
rg -n '\.(sql|py|ts|tsx|yml|yaml|md)\b[^:]' PR.md
# Each hit: confirm whether a line range belongs

# Trait 8: narrative TL;DR for non-trivial PRs (soft check)
LINES=$(wc -l < PR.md)
if [ "$LINES" -gt 200 ]; then
  rg -q '^\*\*The problem\*\*' PR.md \
    && echo "Trait 8: ✓ narrative TL;DR detected" \
    || echo "Trait 8: ⚠ PR is $LINES lines but no '**The problem**' paragraph — consider narrative TL;DR (see §8)"
fi
```

Hard gate: Trait 2 symbolic (zero hits). Soft gates: everything else (review-driven).
