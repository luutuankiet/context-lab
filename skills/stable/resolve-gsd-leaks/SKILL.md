---
name: resolve-gsd-leaks
description: Resolve gsd-lite private-notation leaks in any non-gsd-lite document the agent has authored so the human reader doesn't need to grep a file they can't see. Use when before writing any non-gsd-lite doc (work log, project, arch).
---

# Resolve GSD-Lite Leaks

Enforces **Golden Rule #11 + §6 "Private notation boundary"** of the GSD-Lite Protocol: `LOG-NNN` / `TASK-NNN` / `WORK.md §N` never appear in human-facing docs. This skill is the cleanup pass.

## When to invoke

| User says | Action |
|---|---|
| "resolve the leaks in PR.md" / "clean up X" | Run on the specific file |
| "make this human-readable" / "degsd this" | Same |
| Before pushing any non-`gsd-lite/` doc the agent drafted | Run proactively |
| User asks to publish a PR / ticket / README the agent wrote | Pre-flight: run the acid test FIRST, then this skill if hits >0 |

**Do NOT run on:** files inside `gsd-lite/` (those are the agent's index — refs are correct there). Files the human authored (don't rewrite their words). Skill SKILL.md / protocol files (the meta refs are intentional).

## Workflow

### 1. Acid test — list every leak with line + context

**Local file:**
```bash
rg -n '\bLOG-[0-9]+|\bTASK-[0-9]+|WORK\.md|gsd-lite/' <target_file>
```

**Remote file via MCP** (use the host's grep tool — `<host>:grep`, or the nested form `<host>:<mount>__grep` — per the fs-mcp-schema host table):
```js
mcp__proxy__call_tool_*({
  name: "<host>:grep",
  args: {pattern: "\\bLOG-[0-9]+|\\bTASK-[0-9]+|WORK\\.md|gsd-lite/", path: "<target_file>"}
})
```

If 0 hits → done, report clean. If >0 hits → continue.

### 2. Locate the gsd-lite for this project

Walk up from the target file's directory until you find a sibling `gsd-lite/` dir containing WORK.md. Common patterns:

- `<project>/tmp/projects/<name>/PR.md` → `<project>/tmp/projects/<name>/gsd-lite/WORK.md`
- `<project>/docs/some.md` → `<project>/gsd-lite/WORK.md`
- `<project>/PR.md` → `<project>/gsd-lite/WORK.md`

If not found, ask the user where the gsd-lite lives. Do NOT guess across projects.

### 3. Dedupe + map the leaks

From step 1's output, build a set of unique private refs:
- `LOG-006`, `LOG-007`, `LOG-008` ... (unique LOG IDs)
- `TASK-NNN` (unique task IDs)
- Section refs like `WORK.md §3` or `(line 1276)` (treat as pointers to specific content)

For each unique ID, you'll need to resolve it once and reuse the resolved text wherever it appears in the target doc.

### 4. Resolve each LOG by reading the actual entry

For each unique `LOG-NNN`:

**Find the header** in WORK.md §3 via grep:
```
pattern: "^### \\[LOG-NNN\\]"  (replace NNN with actual number)
path: <project>/gsd-lite/WORK.md
```

Grep returns the line number + `section_end_hint`. Read THAT bounded range (one log, not the whole §3):
```js
mcp__proxy__call_tool_*({
  name: "<host>:read_files",
  args: {files: [{path: ".../WORK.md", reads: [{offset: <grep_line>, limit: <section_end_hint - grep_line>}]}]}
})
```

For LOCAL files just use the Read tool with same bounds.

**Extract** from the log entry:
- The **question** the log answered (1 sentence)
- The **finding** or decision (1-2 sentences)
- The **raw evidence** that made it stick (a SQL row, error message, table row, BQ job ID, file:line, etc.)

That triplet is what replaces every reference to `LOG-NNN` in the target doc. Same evidence, zero filing pointers.

### 5. Plan the rewrite

For each leak hit from step 1, decide the inline resolution. Three patterns work for most cases:

| Leak shape | Inline replacement |
|---|---|
| `(see LOG-NNN)` parenthetical aside | Drop the aside entirely if the surrounding sentence already conveys the finding; else replace with a 1-clause summary |
| `LOG-NNN evidence:` / `Per LOG-NNN:` lead-in | Restate as plain claim + paste the evidence row inline |
| Bulleted "evidence trail" list of LOG refs | Convert each bullet from `LOG-NNN (line X) — topic` to `**Topic** — what was found, with one raw artifact (query / table / BQ job ID / file:line)` |

**File paths and identifiers that aren't private notation stay** — BQ job IDs, git SHAs, CI run IDs, `file:line`, model names, URLs. Those are reproducible references, not the agent's filing system.

### 6. Apply edits in ONE batched call

Per protocol §5, batch all rewrites into a single `edit` call (`files[].edits[]` for remote MCP, parallel Edit calls for local). Never one-edit-at-a-time round trips.

### 7. Re-run the acid test

Same grep from step 1. Expected: 0 hits. If non-zero, you missed something — iterate.

### 8. Report to the user

Tight summary table:

```
| # | Original ref | Inline replacement (1-liner) |
|---|---|---|
| 1 | (see LOG-007) | natural-control technique — waited 28min for fresh prod build with no upstream rebuild between, so dev+prod consumed identical state |
| 2 | LOG-008 results | exhaustive 53-field audit, 45/48 zero-drift, 3 drifts traced to pre-existing antipatterns at models/intermediate/orders_intermediate.sql:160/:768/:776 |
```

Plus: acid-test before/after counts (e.g. "7 leaks → 0").

## Worked example

**Target file:** `tmp/projects/refactor_orders_intermediate/PR.md` on the remote host
**Acid test hits:** 7 (LOG-006, LOG-007, LOG-008, LOG-009 each appearing 1-2 times)

**Sample rewrite — "Detailed evidence trail" block:**

Before:
```
- LOG-006 (line 1108) — Phase 1 Option B grain-fix; per-product revenue drift table
- LOG-007 (line 1276) — natural-control experiment; per-subfield drift table
- LOG-008 (line 1474) — exhaustive 53-field audit; adversarial advisor verdict
```

After (each bullet becomes self-contained, no pointer into a file the reviewer can't see):
```
- **Phase 1 Option B grain-fix** — per-product revenue drift table across 15 products; all subfields zero-drift except revenue (which inherits a pre-existing upstream antipattern). Design-space comparison covered Options A/B/C/D.
- **Natural-control experiment** — waited 28min for a fresh prod build with no upstream rebuild between, so dev + prod consumed identical upstream state. Per-subfield drift bit-perfect to the cent on per-product revenue SUM.
- **Exhaustive 53-field audit** — independent adversarial-advisor agent verified results, refuted 3 narrative hypotheses (conclusion intact), surfaced a pre-existing 12,000-row lookup-duplicate finding faithfully replicated by the refactor.
```

Same information, zero `LOG-NNN`. Reviewer can act on it without grep'ing a file they can't see.

## Anti-patterns

- 🚨 **Skipping the acid test** — eyeballing for leaks misses them. Always grep first.
- 🚨 **Reading entire WORK.md** to resolve refs — `WORK.md §3` is hundreds of KB. Use header-grep + bounded reads (protocol §5 mandate). One log = one bounded read, not a file dump.
- 🚨 **Rewriting `gsd-lite/` files** — the refs are correct there. Skill targets non-gsd-lite docs only.
- 🚨 **Stripping evidence to remove the ref** — if you delete `(see LOG-007)` without inlining the finding, the doc gets weaker, not cleaner. Resolve inline; don't just delete.
- 🚨 **Cross-project gsd-lite hunt** — only look up refs in the gsd-lite that's a sibling of the target doc. Don't grep every gsd-lite on the host.

## Companion to

- **GSD-Lite Protocol §6 "Private notation boundary"** — defines the rule
- **Golden Rule #11** — the one-line enforcement
- **Anti-Patterns table "Private notation leak"** — the failure mode this skill prevents
