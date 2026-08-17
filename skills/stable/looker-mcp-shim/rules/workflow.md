# Workflow — The Looker Dev Loop

## Tool Priority (Read First)

**Always prefer shim tools over upstream [upstream] tools.** Upstream tools lack filter auto-wiring, return bloated output, and waste tokens.

| Need | Use | NOT |
|------|-----|-----|
| Tile data | `run_tile` | `run_dashboard` [upstream] |
| Compiled SQL | `run_tile` (format: "sql") | `query_sql` [upstream] |
| Dashboard overview | `inspect` | `get_dashboards` [upstream] |
| Add tile | `create_tile` | `make_dashboard` [upstream] |
| Add filter | `create_filter` | — |
| Dev/prod mode | `switch_mode` | `dev_mode` [upstream] |
| Validate | `validate` | `validate_project` [upstream] |
| Ad-hoc query | `run_query` | `query` [upstream] |
| Anything else | `retrieve_sdk_methods` → `execute_sdk_code` | — |

**Upstream is last resort** — only for capabilities with no shim equivalent (e.g. `get_project_files`, `update_project_file`).

## Decision Tree

```
What do you need to do?
├─ Understand a dashboard → inspect (see inspect.md)
├─ Get data from a tile → run_tile (see query.md)
├─ Build/modify dashboard → create_tile / update_tile / create_filter (see mutate.md)
├─ Edit LookML code → edit files + git push + reset_to_remote (see git-ops.md)
├─ Validate LookML → validate (see git-ops.md)
├─ Compare dev vs prod → run_tile with force_production=true (see query.md)
├─ Iterate on LookML dashboard → import_lookml_dashboard → mutate UDD → export_dashboard_lookml
└─ Something not covered → retrieve_sdk_methods + execute_sdk_code (see sdk-escape.md)
```

## The Complete Dev Loop

This is the standard cycle for LookML development + QA:

```
1. switch_mode({mode: "dev", branch: "feat/my-branch"})
2. inspect({target: "1234"})  → see all tiles + filters
3. inspect({target: "tile:5678"})  → deep-dive into specific tile
4. run_tile({element_id: "5678"})  → get data (filters auto-applied)
5. [Edit LookML locally, git push]
6. reset_to_remote({})  → sync Looker to latest code
7. validate({})  → check for LookML errors
8. run_tile({element_id: "5678"})  → verify data after changes
9. run_tile({element_id: "5678", force_production: true})  → compare vs prod
```

## Mutation Cycle

To build or modify a dashboard:

```
1. inspect({target: "1234"})  → see current state
2. create_tile({dashboard_id: "1234", title: "Revenue", query: {...}})
3. update_tile({element_id: "5679", query: {vis_config: {type: "looker_pie"}}})
4. create_filter({dashboard_id: "1234", name: "region", ...})
5. inspect({target: "1234"})  → verify mutations
6. run_tile({dashboard_id: "1234", tile: "Revenue"})  → verify data
```

## Key Concepts

**Dev mode**: All changes happen on a git branch. Agent must be in dev mode. Use `switch_mode` to toggle.

**Dashboard filters**: Tiles are wired to dashboard filters via `filter_wiring`. `run_tile` auto-applies dashboard filter defaults. Override specific filters with the `filters` arg.

**Two-level inspection**: `inspect` a dashboard = tile index (~50 tokens/tile). `inspect` a tile = full detail (~200 tokens). Start broad, drill down.

**Partial updates**: `update_tile` merges your changes with the existing query. Only send what changed. Fields, sorts, filters are preserved.

**force_production**: Run a query against production LookML from dev mode. Perfect for parity checks without switching modes.

## LookML Dashboard Iteration Cycle

LookML dashboards are code-defined — you can't mutate tiles/filters via API.
Import as UDD for fast iteration, then export back to LookML:

```
1. inspect({target: "model::dashboard_name"})  → verify it exists, see tiles/filters
2. import_lookml_dashboard({lookml_dashboard_id: "model::dashboard_name", folder_id: "100"})
   → creates UDD copy with numeric ID
3. inspect({target: "4321"})  → verify UDD has all tiles/filters
4. update_tile / create_tile / update_filter  → iterate on UDD (no git!)
5. run_tile({dashboard_id: "4321", tile: "#1"})  → verify data
6. export_dashboard_lookml({dashboard_id: "4321"})  → get LookML YAML
7. Write YAML to .dashboard.lookml file, git push
8. reset_to_remote({}) → validate({}) → inspect model::dashboard_name → verify
```

**Why this workflow?** UDD mutations are instant (API calls). LookML changes require
git commit cycles. Iterate fast on UDD, commit once when satisfied.
