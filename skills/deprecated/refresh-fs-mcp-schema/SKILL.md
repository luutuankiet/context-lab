---
name: refresh-fs-mcp-schema
description: Refresh the fs-mcp schema cache at sandbox-cc/fs-mcp-schema.md after upstream fs-mcp bumps tools or changes signatures. 
---

# Refresh fs-mcp Schema Cache

The cache file `sandbox-cc/fs-mcp-schema.md` is a hand-curated compact form of all 10 fs-mcp tool schemas + the host topology. It exists so future agents can blind-call fs-mcp tools without paying the `retrieve_tools` + `describe_tools` discovery tax every session.

This skill refreshes that cache when fs-mcp upstream changes.

## When to run

- After bumping fs-mcp on any host (`uvx fs-mcp@latest` or rebuild)
- When you see a tool name in the wild that's not in the cache
- When `describe_tools` returns a param the cache doesn't document
- When a host is added to / removed from the fleet (topology table)
- **NOT on a cron** — manual trigger only. Drift is rare; auto-refresh adds noise.

## Procedure

### Step 1 — Pick a canonical host

Default to a direct-routed host that's fast and always on (HTTP transport). Fall back to a second direct-routed host if the first is unreachable. Direct-routed hosts (not behind the shim) return clean descriptions.

```
mcp__proxy__upstream_servers({operation: "list"})
# → pick a direct-routed host with health.level: "healthy"
```

### Step 2 — Pull live schemas

Batch describe all 10 tools in ONE call:

```js
mcp__proxy__describe_tools({
  names: [
    "<host>:read_files", "<host>:edit", "<host>:grep", "<host>:run_command",
    "<host>:create_directory", "<host>:directory_tree",
    "<host>:jq", "<host>:yq", "<host>:query_duckdb", "<host>:list_gsd_lite_dirs"
  ]
})
```

If `describe_tools` returns 11+ tools or a name we don't know → upstream added a tool. Add it to both the canonical list above AND the cache file.

If a tool returns "not found" → upstream removed it. Drop from cache.

### Step 3 — Diff against current cache

Read the current cache:
```js
mcp__proxy__call_tool_read({
  name: "<host>:read_files",
  args: {files: [{path: "dev/sandbox-cc/fs-mcp-schema.md"}]}
})
```

For each tool, compare:
- Required params (additions = breaking, removals = deprecation)
- Optional params (additions = additive, safe)
- Default values
- Enum values for string params (e.g. `yq.input_format`)
- Sentinel strings (`edit.old_string` sentinels)

Build a diff summary like:
```
## Diff vs cached 2026-04-28

ADDED:
  - run_command.timeout_sec_max: int (new)

CHANGED:
  - yq.input_format: added "json5" to enum

REMOVED: (none)

NEW TOOLS: (none)
```

### Step 4 — Hit GitHub for upstream version (optional but recommended)

```js
mcp__proxy__call_tool_read({
  name: "github-gh-cli:shell_execute",
  args: {
    command: ["gh", "api", "repos/luutuankiet/fs-mcp/releases/latest", "--jq", ".tag_name,.published_at"],
    directory: "/tmp"
  }
})
```

Embed the tag + date in the cache header so drift is visible at a glance.

### Step 5 — Rewrite the cache

Update only the changed sections. Bump the header:

```markdown
# fs-mcp Schema Cache

**Source:** github.com/luutuankiet/fs-mcp @ vX.Y.Z (released YYYY-MM-DD)
**Cached:** YYYY-MM-DD (run `/refresh-fs-mcp-schema` after upstream bump).
```

Use `edit` with multi-edit batch — don't rewrite the whole file unless >50% changed (which would warrant user approval per handoff-loop guardrail).

### Step 6 — Verify with a smoke call

After rewriting, do ONE blind call against each host class to prove the cache is correct:

```js
// Direct host:
mcp__proxy__call_tool_read({name: "<host>:directory_tree", args: {max_depth: 1}})

// Shim host single downstream (downstream name == shim name):
mcp__proxy__call_tool_destructive({name: "<shim-host>:<shim-host>__directory_tree", args: {max_depth: 1}})

// Shim host with multiple downstreams (pick one downstream):
mcp__proxy__call_tool_destructive({name: "<shim-host>:<downstream>__directory_tree", args: {max_depth: 1}})
```

If any 401/422/schema error → cache is wrong, fix and re-verify.

### Step 7 — Report to user

```
[REFRESH COMPLETE]

Upstream: vX.Y.Z (was vA.B.C)
Diff: {summary or "no changes"}
Cache: dev/sandbox-cc/fs-mcp-schema.md updated
Smoke checks: {N/N hosts passed}

Next: blind calls against fs-mcp on these hosts now use the new schema.
```

## Caveats

- **Never delete the cache and rewrite from scratch** unless user approves (handoff-loop destructive guardrail). Use `edit` with `match_text` patches.
- **The cache lives at sandbox-cc root** (`fs-mcp-schema.md`), auto-imported by `sandbox-cc/CLAUDE.md` line 3 (`@fs-mcp-schema.md`). If you move the file, update the import line.
- **The `call_with` quirk is real:** direct fs-mcp = `call_tool_read`, proxy-shim routed = `call_tool_destructive`. Don't "fix" this — it's how the shim discloses tools without preserving readOnlyHint annotations.
- **Token budget:** the cache is intentionally compact (~1.5–2k tokens). If it grows past 4k, you've added prose that belongs in the fs-mcp README, not the cache.
