---
name: progress-check
description: Session navigator for Tableau-to-Looker migrations. Detects current phase by checking which artifacts exist, advises what to do next, whether the human needs to stay or can hand off, and when to fork to a fresh session. Use when the user asks "where are we?", "what's next?", "status?", or at the start of any migration session.
argument-hint: "[workbook-path]"
---

# Progress Check

> **You are the session navigator.** Your job: figure out where we are, tell the human, and advise what's next.

## How to Run

1. Ask the user which workbook (if not obvious from context)
2. Check the workbook directory for artifacts
3. Report phase + next action + whether human is needed

## Step 1: Find the Workbook

If the user didn't specify, scan for workbooks:

```
ls workspace/workbooks/
```

If multiple workbooks exist, ask which one. If only one, proceed.

## Step 2: Check Artifacts

```
ls workspace/workbooks/<name>/
```

Map what exists to the current phase:

| Artifact Found | Meaning |
|---------------|--------|
| `src/<name>.twb` only | Nothing started yet |
| `_migration_contract.md` | Extraction + contract done |
| `_tableau_visual_spec.md` | Screenshots captured + annotated |
| Contract has "Decision Log" with BQ results | BQ verification done |

Also check the LookML branch:

```
ls workspace/bitbucket/branches/feat__<name>/
```

| Branch State | Meaning |
|-------------|--------|
| Directory doesn't exist or empty | No build yet |
| Has `.view.lkml` + `.explore.lkml` files | Build started/complete |
| Has `dashboards/` directory | Dashboards written |

## Step 3: Report

Use this exact format:

```
Phase: [0 / 0.5 / 0.75 / 1 / 1.5 / Complete]
Status: [one-line description of where things stand]

Artifacts:
  Contract:    [exists / missing]
  Visual spec: [exists / missing]
  LookML:      [N files on branch / missing]
  Dashboards:  [N files / missing]

Next action: [what to do]
Human needed: [Yes -- reason / No -- agent can run autonomously]
```

## Step 4: Advise on Session Health

If this is a continuing session (not fresh):
- If 20+ tool calls have been made, recommend forking
- If the next phase needs the human but they want to leave, capture findings first
- If the next phase is autonomous, offer to proceed or generate a handoff prompt

## Step 5: Generate Handoff Prompt (if forking)

When the session should fork, generate an exact copy-paste prompt:

```
Fork prompt for next session:
---
Migration workbook: workspace/workbooks/<name>/
Artifacts:
- _migration_contract.md [exists/approved]
- _tableau_visual_spec.md [exists/missing]
Target branch: feat__<name>
Target model: <model>.model.lkml

Load migration-pipeline skill.
Resume at Phase [N]: [description].
[Key context from this session, e.g. "BQ verification found 5 name
variants -- already fixed in contract Decision Log."]
---
```

## Phase Reference

| Phase | Name | Human Needed | Skills to Load |
|-------|------|:------------:|---------------|
| 0 | Extract | No | migration-pipeline (spawns twb-deep-extraction subagent) |
| 0.5 | Contract | **Yes** | migration-pipeline |
| 0.75 | BQ Verify | No | migration-pipeline + bq-tile-verification |
| 1 | Build | No | migration-pipeline + looker-mcp-shim |
| 1.5 | Dashboard QA | Final review only | looker-mcp-shim |

## Response Format

After reporting status, close every response with:

```
---
High level (strategic)
- [topic] -- [why] -- [impact]

Low level (tactical)
- [action] -- [trigger] -- [unblocks]
```
