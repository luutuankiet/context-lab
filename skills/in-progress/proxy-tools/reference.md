# MCP Proxy Tool Pipeline

> **Portable reference.** This document is agent-agnostic — it describes how to use
> [mcpproxy-go](https://github.com/smart-mcp-proxy/mcpproxy-go) from any coding agent
> that connects via MCP. Tool names below are the **server-native** names. Your agent
> may prefix them (e.g., `mcp__myalias__retrieve_tools`). Adapt the prefix to your environment.

---

## Step 0: Identify Your Proxy

Before calling anything, identify which of your connected MCP servers is the proxy.

**Fingerprint — look for a server exposing ALL of these tools:**

| Core tool | Purpose |
|-----------|---------|
| `retrieve_tools` | Search across all upstream servers for relevant tools |
| `call_tool_read` | Execute a read-only tool on an upstream server |
| `call_tool_write` | Execute a write tool on an upstream server |
| `call_tool_destructive` | Execute a destructive tool on an upstream server |

**Supporting tools (also present):**

| Tool | Purpose |
|------|---------|
| `upstream_servers` | List, add, remove, patch upstream MCP servers |
| `list_registries` | Browse MCP server registries |
| `search_servers` | Find new servers to add |
| `quarantine_security` | Manage quarantined servers |
| `read_cache` | Retrieve truncated responses |
| `tool_search_tool_bm25_*` | BM25 full-text search across all tool names |

Once identified, note the prefix your agent uses for that server. All examples below
use `{PROXY}` as a placeholder — substitute your actual prefix.

---

## Step 1: Discover the Target Tool

Use `retrieve_tools` with a **natural language query** describing what you want to do.

```
{PROXY}retrieve_tools(query="what you want to accomplish", limit=5)
```

**What you get back per tool:**

| Field | What it tells you |
|-------|------------------|
| `name` | Exact tool name, format: `server-name__tool_name` |
| `call_with` | Which execution variant: `call_tool_read`, `call_tool_write`, or `call_tool_destructive` |
| `inputSchema` | The exact parameters the tool accepts — types, required fields, defaults |
| `server` | Which upstream server owns this tool |
| `annotations` | Behavioral hints like `readOnlyHint` |

**You can also use BM25 search** for keyword-based discovery:

```
{PROXY}tool_search_tool_bm25_*(query="exact keywords")
```

This returns tool name references only (no schema). Follow up with `retrieve_tools` to get the full schema.

---

## Step 2: Execute with the Correct Variant

Use the variant specified in `call_with` from Step 1.

```
{PROXY}call_tool_read(
  name="server:tool_name",
  args_json='{"param": "value"}',
  intent_reason="why you are calling this",
  intent_data_sensitivity="public|internal|private|unknown"
)
```

### Critical Details

**Tool name format changes between discovery and execution:**

| Context | Format | Example |
|---------|--------|---------|
| Discovery result (`name` field) | `server__tool` (double underscore) | `bq-main__execute_sql` |
| Execution (`name` param) | `server:tool` (colon) | `everything:bq-main__execute_sql` |

The `server` value comes from the `server` field in the `retrieve_tools` response.
Combine as: `{server}:{name}`

**Parameter format:**

| Param | Type | Notes |
|-------|------|-------|
| `name` | string | `server:tool_name` — colon-separated |
| `args_json` | **JSON string** | NOT a dict/object — must be serialized: `'{"sql": "SELECT 1"}'` |
| `intent_reason` | string | Human-readable why — for audit trail |
| `intent_data_sensitivity` | string | One of: `public`, `internal`, `private`, `unknown` |

---

## Step 3: Handle Truncated Responses

Large responses are truncated by mcpproxy. When this happens, the response includes a cache key.

```
{PROXY}read_cache(key="<cache_key>", offset=0, limit=50)
```

Use `offset` and `limit` to paginate through results.

---

## Schema Caching Within a Session

Once you have called `retrieve_tools` for a tool and received its `inputSchema`,
that schema is in your conversation context. **Do NOT re-discover the same tool
within the same session.** Go straight to Step 2.

This matters for token efficiency — every redundant discovery call wastes context.

---

## Upstream Server Management

```
{PROXY}upstream_servers(operation="list")
{PROXY}upstream_servers(operation="add", name="my-server", url="http://localhost:3000")
{PROXY}upstream_servers(operation="patch", name="my-server", enabled=true)
{PROXY}upstream_servers(operation="tail_log", name="my-server", lines=100)
```

New servers are **auto-quarantined** for security. Use `quarantine_security` to review and approve.

---

## Common Mistakes

| Mistake | Why it fails | Correct |
|---------|-------------|---------|
| Calling `call_tool_*` without `retrieve_tools` first | You don't know the server name, param schema, or correct variant | Always discover first |
| Using `tool_name` param | The param is called `name` | `name="server:tool_name"` |
| Passing args as a dict | `args_json` expects a string | `args_json='{"key": "value"}'` |
| Using `server__tool` format in execution | Discovery uses `__`, execution uses `:` | `name="server:tool"` not `name="server__tool"` |
| Guessing tool parameters | Every tool has a unique schema | Read `inputSchema` from `retrieve_tools` |
| Re-discovering a tool you already found this session | Wastes tokens | Use cached schema from earlier in conversation |

---

## Philosophy

This pipeline exists because **proxy tools are deferred** — their schemas are not
loaded at conversation start. The agent sees tool names but has zero knowledge of
their parameters until it explicitly loads the schema.

The core discipline: **never call what you haven't inspected.**

This mirrors the broader principle: *echo before execute* — understand the interface
before invoking it. Guessing parameters from tool names is the #1 source of wasted
turns and tokens when working through a proxy.