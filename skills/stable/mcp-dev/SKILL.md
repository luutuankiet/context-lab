---
name: mcp-dev
description: "MCP server development, testing, and hot-connect. Use when: debugging MCP servers, testing new/updated MCP endpoints, connecting to arbitrary MCP servers via passthru mode."
user-invocable: true
---

# MCP Dev & Debug Toolkit

## When This Activates

- User says "test this MCP server", "debug MCP", "connect to MCP"
- Troubleshooting MCP server connectivity or tool registration
- Hot-connecting to a new or experimental MCP server
- **PROACTIVE:** Agent is editing MCP server source code (see Hot Dev Loop below)

> **Wiring new servers to mcpproxy or managing the proxy fleet?** Use the **manage-mcp-proxy** skill instead.

## Shim Behavior (`@luutuankiet/mcp-proxy-shim` v1.3.3+)

Sits between Claude Code and mcpproxy-go. Transports: **stdio** and **HTTP Streamable** only.

- Adds `structuredContent` to text-only responses (fixes Claude Code TUI rendering)
- **Does NOT add SC when response contains images** — Claude Code ignores `content` when SC is present, so images would go blind. This is intentional.
- If upstream already returns SC, the shim preserves it (does not overwrite)
- Test fixture: `mcp-proxy-shim/test/sc-test-server.mjs`

## Hot Dev Loop (PROACTIVE)

**STOP GATE:** About to `docker compose build`? STOP. Test locally first.

```
Edit -> Typecheck -> Start on dev port -> Test via passthru
  -> Fix -> Restart dev (2s) -> Test again
    -> All green? -> THEN Docker rebuild (once) -> proxy-fleet restart
```

### Node.js
```bash
# Edit, then:
npx tsc --noEmit
PORT=9998 npx tsx src/index.ts &

# Test via passthru (returns clean JSON — always use this).
# ALWAYS pin @latest — a stale cached version in ~/.npm/_npx will crash with
# "Unknown command: @luutuankiet/mcp-proxy-shim" (that's npm, not npx). Fix: rm -rf ~/.npm/_npx.
MCP_PORT=3459 nohup bash -c 'exec npx -y @luutuankiet/mcp-proxy-shim@latest passthru --url http://localhost:9998/mcp' > /tmp/shim.log 2>&1 &
disown
curl -s localhost:3459/call/my_tool -d '{"args":{"key":"val"}}'

# Iterate
kill %1 && PORT=9998 npx tsx src/index.ts &

# Deploy (once, when done)
docker compose build && docker compose up -d
# Then: manage-mcp-proxy skill to restart upstream
```

### Python
```bash
pip install -e . && python -m fs_mcp --port 9998 --no-ui &
# Same passthru test cycle
```

### Backgrounding gotcha (npx + `&` inside Claude Code's Bash tool)
**Bare `cmd &` and `run_in_background: true` both make npx fail with `Unknown command: @<pkg>`** (npm's error, not npx's) when the cache isn't already warm. Foreground works; background fails. Reliable pattern:

```bash
nohup bash -c 'exec npx -y @luutuankiet/mcp-proxy-shim@latest passthru -- uv run your-server' > /tmp/shim.log 2>&1 &
disown
```

Hypothesis: no controlling TTY + no fresh-shell wrap → npx arg dispatch falls through to `npm`. The `nohup bash -c 'exec ...'` isolates it in a clean subshell with its own process group.

### Port clash
`MCP_PORT` defaults to **3456**. Assume it's taken on dev boxes — pass `MCP_PORT=3459` (or another free port) explicitly. Don't trust the default.

## Passthru — The Testing Tool

Always use passthru for dev testing. It connects to any MCP server and returns **clean JSON REST**.

```bash
# HTTP server
npx -y @luutuankiet/mcp-proxy-shim@latest passthru --url http://localhost:9998/mcp

# Spawn subprocess directly (pass env via --env; use --cwd for the subprocess working dir)
MCP_PORT=3459 npx -y @luutuankiet/mcp-proxy-shim@latest passthru \
  --cwd /path/to/server \
  --env FOO=bar \
  -- uv run your-server

# Config file
npx -y @luutuankiet/mcp-proxy-shim@latest passthru --config server.json
```

Endpoints:

| Endpoint | What it does |
|----------|-------------|
| `GET /health` | Status + tool count |
| `GET /tools` | Tool list. `?q=keyword` to search |
| `GET /tools/:name` | Full schema with inputSchema |
| `POST /call/:name` | Call tool. Body: `{args: {...}}` |
| `POST /restart` | Reconnect upstream |

### `/call/:name` response gotcha — use `curl -v`, not `curl -s`
In shim v1.6+, plain `curl -s .../call/:name` writes a dehydrated, schema-like representation to stdout:

```
{ client_id_suffix: string, exists: bool, ... }   # NOT valid JSON
```

The wire body IS real JSON — `curl -v` (verbose) dumps it after the headers. Workaround until fixed upstream:

```bash
curl -sv localhost:3459/call/my_tool -d '{"args":{}}' 2>&1 | awk '/^\{/,/^\}/' | tail -1
```

Filing upstream. Until patched, **always `-v`** when you need to parse the response.

### Daemon Mode (cloud/subagent testing)

```bash
MCP_URL=http://localhost:8000/mcp npx -y @luutuankiet/mcp-proxy-shim daemon
curl -s localhost:3456/retrieve_tools -d '{"query":"my new tool"}'
```

## Debug Scenarios

> **Proxy ops** (restart upstreams, quarantine, add servers): **manage-mcp-proxy** skill.

| Symptom | Fix |
|---------|-----|
| `retrieve_tools` returns 0 | Function-oriented query, bump limit |
| `Session not found` | Re-initialize, reuse session ID |
| `405 Method Not Allowed` | Server doesn't support Streamable HTTP — use stdio |
| Tools register, calls fail | `describe_tools` to check inputSchema |
| TUI blank on tool results | Update shim to v1.3.0+ |
| Model blind to images | Shim v1.3.2+ — mixed content skips SC by design |
| `Unknown command: "@<pkg>"` (from npm) | Stale npx cache. `rm -rf ~/.npm/_npx/` + pin `@latest` |
| Shim works foreground, fails with `&` / `run_in_background` | Wrap in `nohup bash -c 'exec npx ...' > log 2>&1 &; disown` |
| `/call/:name` returns `{ key: type }` instead of JSON values | Shim v1.6 bug — use `curl -v` to read the real wire body |
| `MCP_PORT` default 3456 already in use | Always pass `MCP_PORT=<free-port>` explicitly |

## Environment

| Variable | Purpose |
|----------|---------|
| `MCP_URL` | Upstream URL (daemon/passthru/serve) |
| `MCP_PORT` | Listen port (default: 3456 daemon/passthru, 3000 serve) |
| `MCP_APIKEY` | Optional auth for daemon/serve |
