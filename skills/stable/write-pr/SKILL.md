---
name: write-pr
description: Render evidence-driven Pull Requests with inline file:line citations, spoon-fed SQL+results, vanilla <details> collapsible sections, and dbt-Jinja-safe templating. Use proactively when writing a PR for a non-trivial code change that deserves a detailed evidence trail — refactors, performance work, schema migrations, model parity validations. Companion to npm package @luutuankiet/write-pr.
---

# write-pr — Evidence-Driven PR Templating

## What this is

A two-step compile pattern for writing Pull Requests at the density of a 3-tier evidence stack — without paying for raw tool I/O in agent context.

The skill describes **8 quality traits** a good PR has (see `rules/good-pr-traits.md`). It does NOT prescribe a section outline — structure is the agent's choice, the traits apply regardless.

Reference quality bar: SCD-2 pre-explode refactor PR with per-product SUM validation, exhaustive 56-field schema audit, canonical multiset decomposition, plus CI-run failure attribution. 62 KB / 890 lines. Zero reviewer context-switching.

## When to use this skill

Proactively, when:
- Writing a PR for a non-trivial refactor, perf optimization, schema migration, or data-pipeline change
- The reviewer needs to see SQL + results inline (not "here's a BQ link, go run it yourself")
- You have file:line citations that need to be expanded with code context
- The PR has multi-section structure (TL;DR / Changes / Validation / Decisions / Appendix)
- You want to fold long evidence blocks into vanilla GitHub `<details>` for scannability

Skip this skill for trivial PRs (typo fixes, single-line config tweaks, dependency bumps).

## The two-step compile pattern

```
Agent → 1. Gather evidence on the working host:
          - Run BQ/DuckDB queries → dump prettyjson to evidence/queries/*.json
          - Fetch CI artifacts → save to evidence/ci_runs/*.json
          - (Optional) save shaped before/after JSON → evidence/queries/*.json for delta_table
        2. Write pr.md.j2 referencing those disk paths via Nunjucks helpers
        3. Invoke: npx -y @luutuankiet/write-pr render \
             --template pr.md.j2 \
             --evidence ./evidence \
             --out PR.md
        4. Pre-flight check (rg for private notation, see rules/private-notation.md)
        5. Paste rendered PR.md into GitHub PR body
```

The render script reads the disk evidence and applies filters — your context never holds raw tool I/O.

## Custom Jinja delimiters (MANDATORY)

Templates use `[[ ]]` for variables and `[% %]` for blocks.

```jinja
[[ load_json('queries/q1.json') | md_table ]]

[% if meta.foo %][[ meta.foo ]][% endif %]

[# this is a comment #]
```

**Why:** default `{{ }}` collides with dbt-Jinja inside code-fence evidence and silently renders to empty string.

## Filter reference

| Filter | Use | Example |
|---|---|---|
| `md_table` | JSON array → markdown table | `[[ load_json('q.json') \| md_table ]]` |
| `json_pretty` | Value → fenced \`\`\`json block | `[[ obj \| json_pretty ]]` |
| `gh_callout` | GitHub callout (TIP/NOTE/IMPORTANT/WARNING/CAUTION) | `[[ 'TIP' \| gh_callout('schema is bw-compat') ]]` |
| `code_expand` | Read source file → fenced code block w/ file:line header | `[[ 'src/foo.sql' \| code_expand(lines='10-25') ]]` |
| `delta_table` | Two JSON arrays → before/after table w/ computed Δ | `[[ before \| delta_table(after) ]]` |
| `fold` | Wrap ANY content in `<details><summary>` block | `[[ rows \| md_table \| fold('Validation') ]]` |

Full signatures: `rules/placeholder-vocab.md`. Two known custom-delim edge cases: `rules/template-gotchas.md`.

## Snippets (composable section patterns)

11 snippets at `snippets/*.j2` covering the most-frequent sections from a survey of 7 real PRs (5/7: TL;DR + Validation + Changes; 4/7: Before/After + Checklist; 3/7: Mermaid flowchart):

| Snippet | Section | Filters used |
|---|---|---|
| `narrative_tldr.j2` | 4-paragraph executive narrative ABOVE the metrics table (Trait 8) | — |
| `tldr_kv_table.j2` | Top-of-PR metrics summary | `md_table` |
| `manifest_tip_header.j2` | TIP callout + ticket link | `gh_callout` |
| `before_after_img_table.j2` | 2-col before/after screenshots | — |
| `before_after_code.j2` | Stacked before/after code | — |
| `design_decision.j2` | Options table + chosen + rationale | `md_table` |
| `numbered_validation.j2` | `### N. <Title>` sub-section | — |
| `mermaid_flowchart.j2` | Inline mermaid block skeleton (no filter dep) | — |
| `sql_appendix.j2` | Q-numbered SQL with file:line header | `code_expand` |
| `delta_table_perf.j2` | Before/after comparison (perf, config, schema diff) | `delta_table` |
| `checklist.j2` | Bottom-of-PR reviewer checklist | — |

Two usage modes: copy-paste (most agents) or `[% include 'snippets/X.j2' %]` (the renderer walks up from cwd / template dir to find the install location). See `snippets/README.md`.

## Rules of thumb

- `rules/good-pr-traits.md` — **READ FIRST.** The 8 quality traits a good PR has (spoon-feed evidence, resolve private context [symbolic + verbal], collapse at section boundary, anchor prior runs, text-fallback for auth-gated links, hypothesis tag, file:line citations, narrative-first TL;DR). Describes traits, NOT a template.
- `rules/workflow.md` — the 5-step agent workflow (gather → template → render → pre-flight greps → paste)
- `rules/disk-convention.md` — evidence/ directory layout (queries/code/diagrams/ci_runs/images) + cwd vs evidence vs root_path
- `rules/placeholder-vocab.md` — full filter + global signatures with examples
- `rules/private-notation.md` — pre-render grep checklist (NEVER ship LOG-NNN / TASK-NNN / gsd-lite refs) + client-info scrubbing
- `rules/callout-gotcha.md` — GitHub `[!TIP]` does NOT render styled inside `<details>` (plain text only); put callouts outside
- `rules/root-path.md` — frontmatter `root_path:` for repo-relative file:line citations
- `rules/template-gotchas.md` — two custom-delim edge cases (`[[[ ]]]` trap, literal-filter-in-prose) + workarounds

## Quick test (verify install)

```bash
# Render the bundled minimal example. SKILL_DIR is the base directory this
# skill was loaded from -- the harness states it when it injects this file.
# Do not use $CLAUDE_PLUGIN_ROOT: it is empty in a Bash call.
SKILL_DIR=<this skill's base directory>
cd <your-project>
npx -y @luutuankiet/write-pr render \
  --template "$SKILL_DIR"/examples/minimal/pr.md.j2 \
  --evidence "$SKILL_DIR"/examples/minimal/evidence \
  --out /tmp/test-pr.md
diff /tmp/test-pr.md "$SKILL_DIR"/examples/minimal/pr.rendered.md
# Expected: zero diff output
```
