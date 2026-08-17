---
name: mcp-daemon
description: MCP daemon API reference and troubleshooting. Daemon auto-starts in cloud sessions via UserPromptSubmit hook — this skill is for manual fallback and API docs.
user-invocable: true
---

# MCP Daemon — Cloud Session Bridge

## Lifecycle

**The daemon is auto-managed.** A `UserPromptSubmit` hook (`ensure-mcp-daemon.sh`) handles startup and health monitoring every turn in cloud sessions. You should not need to start it manually.

The hook:
- Gates on `CLAUDE_CODE_REMOTE=true` (no-op on desktop)
- Health-checks before starting (idempotent)
- Non-blocking (inference continues even if daemon fails)
- Injects status into context via stdout

### Manual Fallback

If the hook fails or you need to restart manually:
```bash
# One-liner recovery (same script the hook runs)
bash .claude/hooks/ensure-mcp-daemon.sh

# Or start directly
export $(cat .cloud.env | xargs) && nohup npx -y @luutuankiet/mcp-proxy-shim@latest daemon > /tmp/mcp-daemon.log 2>&1 &
```

### Health Check
```bash
curl -s localhost:<port>/health
# → {"ok":true,"sessionId":"mcp-sess...","uptime":42,"callCount":5}
```

---

## API Reference

### `POST /retrieve_tools` — Discover upstream tools

```bash
curl -s localhost:<port>/retrieve_tools -d '{"query":"read files"}'
```

Response: Array of tools with `server`, `name`, `call_with`, `inputSchema`.

### `POST /describe_tools` — Full schema hydration

```bash
curl -s localhost:<port>/describe_tools -d '{"names": ["read_files"]}'
```

Returns full tool entries with complete `inputSchema` — use after `retrieve_tools` to get exact parameter shapes before calling.

### `POST /call` — Execute an upstream tool

```bash
curl -s localhost:<port>/call -d '{
  "method": "call_tool_read",
  "name": "<server>:read_files",
  "args": {
    "files": [{"path": "~/dev/gsd-lite/PROJECT.md", "head": 20}]
  },
  "reason": "read project context"
}'
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `method` | string | ✅ | `call_tool_read`, `call_tool_write`, or `call_tool_destructive` |
| `name` | string | ✅ | `server:tool_name` (colon-separated, from `retrieve_tools`) |
| `args` | object | ✅ | **Native JSON object** — daemon handles serialization to `args_json` |
| `reason` | string | ❌ | Intent audit trail (default: "daemon call") |
| `sensitivity` | string | ❌ | `public`, `internal`, `private`, `unknown` (default: "internal") |

### `POST /exec` — Run code on proxy

```bash
curl -s localhost:<port>/exec -d '{"code": "return Object.keys(servers)"}'
```

### `POST /reinit` — Force new MCP session

```bash
curl -s localhost:<port>/reinit
```

### `POST /proxy_admin` — Proxy fleet management (passthrough)

REST passthrough to the `proxy_admin` MCP tool. Same args as the tool — see [manage-mcp-proxy skill](../manage-mcp-proxy/docs/proxy-admin-reference.md) for full operations reference.

```bash
curl -s localhost:<port>/proxy_admin -d '{"operation": "list"}'
curl -s localhost:<port>/proxy_admin -d '{"operation": "inspect_server", "server_name": "gh-cli"}'
```

---

## Common Patterns

### Batch file read (single call)

```bash
curl -s localhost:<port>/call -d '{
  "method": "call_tool_read",
  "name": "<server>:read_files",
  "args": {
    "files": [
      {"path": "~/dev/gsd-lite/PROJECT.md"},
      {"path": "~/dev/gsd-lite/WORK.md", "head": 50}
    ]
  }
}'
```

### Grep across codebase

```bash
curl -s localhost:<port>/call -d '{
  "method": "call_tool_read",
  "name": "<server>:grep_content",
  "args": {
    "pattern": "OOM",
    "search_path": "~/dev/gsd-lite",
    "compact": true
  }
}'
```

### Edit a file

**ALWAYS use `curl -d @file` for edits** — never inline JSON. Bash mangles shell metacharacters (`'`, `$`, `()`, backticks) inside match_text/new_string.

**Pre-edit read rule:** Read the target section with **`compact: false`** first. Default `compact: true` strips whitespace — the compressed output won't match actual file content.

```bash
# Step 1: Read exact verbatim text
curl -s localhost:<port>/call -d '{
  "method": "call_tool_read",
  "name": "<server>:read_files",
  "args": {"files": [{"path": "path/to/file.md", "start_line": 40, "end_line": 55}], "compact": false}
}'

# Step 2: Write payload to temp file
mkdir -p /tmp/mcp-edits
cat > /tmp/mcp-edits/edit-001.json << 'JSONEOF'
{
  "method": "call_tool_write",
  "name": "<server>:edit_files",
  "args": {
    "files": [{
      "path": "~/dev/gsd-lite/WORK.md",
      "edits": [{"match_text": "exact text", "new_string": "replacement"}]
    }]
  }
}
JSONEOF

# Step 3: Send via @file
curl -s localhost:<port>/call -d @/tmp/mcp-edits/edit-001.json
```

### Large payloads (artifacts, JSX, bulk ops)

Any `curl -d` with >2KB body or special characters → always use `@file`. Pattern:
```bash
mkdir -p /tmp/mcp-edits
cat > /tmp/mcp-edits/artifact-001.json << 'JSONEOF'
{ ... your JSON ... }
JSONEOF
curl -s localhost:<port>/call -d @/tmp/mcp-edits/artifact-001.json
```

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `curl: (7) Failed to connect` | Daemon not running | `bash .claude/hooks/ensure-mcp-daemon.sh` |
| `{"error":"Request timeout"}` | Proxy unreachable | Check `https_proxy` env, try `curl -v` to proxy URL |
| `{"error":"Session refreshed, retry"}` | MCP session expired | Just retry — daemon auto-reinits |
| `No client found for server: X` | Wrong server name | Use `retrieve_tools` to discover correct `server:name` |

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `MCP_PORT` | `<port>` | Port to listen on |
| `MCP_URL` | From `.cloud.env` | mcpproxy-go StreamableHTTP endpoint |

## Architecture

```
Claude (clean JSON) → curl localhost:<port> → mcp-proxy-shim daemon → MCP proxy → upstream
                    ← unwrapped response   ←                       ←           ←
```
