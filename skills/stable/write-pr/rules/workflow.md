# Agent Workflow

The two-step compile pattern that makes write-pr useful.

## Step 0: Read `rules/good-pr-traits.md` first

Before writing a single line of template, internalize the 7 quality traits (spoon-feed evidence, resolve-private-context, collapse-at-section-boundary, anchor-prior-runs, text-fallback-for-auth-gated-links, hypothesis-tag, file-citation-line-range). They apply to every section regardless of which structure you choose.

## Step 1: Gather evidence ON the working host

Don't pull tool I/O through your context. Dump it to disk:

```bash
# BQ / DuckDB / SQL queries
bq query --format=prettyjson '...' > evidence/queries/q_summary.json
duckdb -json -c '...' > evidence/queries/q_validation.json

# CI artifacts
gh api repos/OWNER/REPO/actions/runs/RUN_ID/artifacts > evidence/ci_runs/run_RUN_ID.json
# (or dbt cloud cli, etc.)

# Mermaid diagrams (write directly)
cat > evidence/diagrams/data_flow.mmd <<'EOF'
flowchart LR
    A --> B
EOF
```

## Step 2: Write pr.md.j2 referencing those disk paths

Use `load_json(...)` / `load_text(...)` to pull evidence in at render time:

```jinja
---
title: "Refactor orders_intermediate: 96% wall reduction"
root_path: "/repo/root"
---

[[ load_json('queries/q_summary.json') | md_table ]]

[[ 'models/intermediate/orders_intermediate.sql' | code_expand(lines='120-185') ]]
```

## Step 3: Render

```bash
npx -y @luutuankiet/write-pr render \
  --template pr.md.j2 \
  --evidence ./evidence \
  --out PR.md
```

## Step 4: Pre-flight grep (MANDATORY)

```bash
# Check for private notation leaks — see rules/private-notation.md
rg -n '\bLOG-[0-9]|\bTASK-[0-9]|WORK\.md|gsd-lite/' PR.md
# Expected: zero matches — HARD GATE

# Check for unparsed variables (silent-empty renders)
rg -n '\[\[ ' PR.md
# Expected: zero matches — see rules/template-gotchas.md
```

Then walk the deeper trait audit at the bottom of `rules/good-pr-traits.md` (orphan "see X" pointers, verbal private-context, top-level-section wrap count, hypothesis tags, file:line ranges). The trait audit is review-driven; the two greps above are the only HARD gates.

## Step 5: Paste rendered PR.md into GitHub PR body

Then paste any screenshots directly into the GitHub editor — GitHub auto-converts to `<img>` tags. See `rules/disk-convention.md` for why we don't template image refs.

## Why this pattern

The render step reads evidence from disk and applies filters; raw tool I/O never enters your context. Result: PR-grade evidence density (62 KB / 890 lines for a real refactor PR) on ~5 KB of template + the disk evidence files.
