---
name: looker-mcp-shim
description: REQUIRED before using any Looker MCP tools. Covers QA, data verification, dashboard inspection, tile queries, mutations, LookML editing, git sync, validation. Read rules/*.md for correct tool usage and workflow order.
metadata:
  tags: looker, lookml, mcp, dashboard, bigquery, data-engineering
---

## When to use

ALWAYS read this skill BEFORE calling any Looker MCP tool. Use when:

- QA / data verification / comparing Tableau vs Looker
- Inspecting dashboards and tiles (fields, SQL, filters, vis config)
- Getting tile data (use `run_tile` NOT `run_dashboard` or `query`)
- Creating, modifying, and deleting dashboard tiles and filters
- Editing LookML, pushing to git, syncing Looker, validating
- Executing any of Looker's 469 API methods via SDK discovery

**CRITICAL:** To get data from a tile, use `run_tile` with `dashboard_id` + `tile` (e.g. `"#1"` or `"Revenue"`). It auto-applies dashboard filters. Do NOT manually reconstruct filters.

## Tool Priority — Shim First, Upstream Last

Our hand-rolled shim tools are **always preferred** over upstream equivalents. They have filter auto-wiring, better error messages, and token-efficient output. Upstream tools are fallbacks only.

| Need | Use | NOT (upstream fallback) | Why shim wins |
|------|-----|------------------------|---------------|
| Tile data / SQL | `run_tile` | `run_dashboard`, `query_sql`, `query` | Auto-wires dashboard filters, ordinal refs, async fallback |
| Dashboard overview | `inspect` | `get_dashboards`, `get_looks` | URL-smart, two-level depth, token-efficient |
| Add tile | `create_tile` | `make_dashboard` | Handles two-step query creation automatically |
| Edit tile | `update_tile` | — | Partial merge — only send what changed |
| Add filter | `create_filter` | — | Simpler interface, validates inputs |
| Dev/prod toggle | `switch_mode` | `dev_mode` | Branch selection + wildcard + confirmation |
| Validate LookML | `validate` | `validate_project` | Structured file:line errors |
| Ad-hoc query | `run_query` | `query`, `query_sql` | Filter auto-wiring + async fallback |
| Anything else | `retrieve_sdk_methods` → `execute_sdk_code` | any upstream tool | Covers all 469 API methods |

**Rule:** If a shim tool exists for your task, use it. Only reach for upstream tools when the shim cannot do the job (e.g. `get_project_files`, `update_project_file` for LookML file I/O — no shim equivalent yet).

## Tools Overview

| Tool | Purpose |
|------|--------|
| `inspect` | Dashboard overview or tile detail (URL-smart input) |
| `run_tile` | **PRIMARY tool for tile data/QA.** Auto-applies dashboard filters |
| `run_query` | Ad-hoc explore query |
| `create_tile` | Add tile to dashboard |
| `update_tile` | Modify tile (partial merge — only send what changed) |
| `delete_tile` | Remove tile |
| `create_filter` | Add dashboard filter |
| `update_filter` | Modify filter |
| `delete_filter` | Remove filter |
| `import_lookml_dashboard` | Import LookML dashboard as editable UDD copy for fast iteration |
| `export_dashboard_lookml` | Export any dashboard as LookML YAML for committing to code |
| `switch_mode` | Toggle dev/prod mode with branch |
| `reset_to_remote` | Sync Looker project to git HEAD |
| `validate` | LookML validation with file:line errors |
| `retrieve_sdk_methods` | Search 469 SDK methods by keyword |
| `describe_sdk_method` | Get full params + code example for a method |
| `execute_sdk_code` | Run arbitrary SDK code |

## Workflow Guides

Read these before starting:

- [rules/workflow.md](rules/workflow.md) — **Start here.** The complete dev loop and decision tree
- [rules/inspect.md](rules/inspect.md) — Dashboard/tile inspection patterns
- [rules/query.md](rules/query.md) — Running queries, filter auto-wiring, async fallback
- [rules/mutate.md](rules/mutate.md) — Creating/updating/deleting tiles and filters
- [rules/git-ops.md](rules/git-ops.md) — Dev/prod mode, git sync, LookML validation
- [rules/sdk-escape.md](rules/sdk-escape.md) — SDK method discovery + code execution
- [rules/patterns.md](rules/patterns.md) — Common recipes: migration QA, dashboard cloning, bulk ops
