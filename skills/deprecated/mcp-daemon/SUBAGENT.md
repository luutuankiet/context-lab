# MCP Access for Subagents

## Daemon is Auto-Managed

A `UserPromptSubmit` hook ensures the daemon is running on `localhost:<port>` in cloud sessions.
You don't need to start it — just use the API below.

**If curl fails** (daemon died mid-flight), recover with one line:
```bash
bash .claude/hooks/ensure-mcp-daemon.sh
```
Then retry your call.

## API Quick Reference

### Find tools
```bash
curl -s localhost:<port>/retrieve_tools -d '{"query": "YOUR SEARCH TERMS"}'
```
Returns `tools[]` with `server`, `name`, `call_with` fields.

### Get full schema (do this before first call to any tool)
```bash
curl -s localhost:<port>/describe_tools -d '{"names": ["server:tool_name"]}'
```

### Call a tool
```bash
curl -s localhost:<port>/call -d '{
  "method": "CALL_WITH_VALUE",
  "name": "SERVER:TOOL_NAME",
  "args": { NATIVE_JSON_ARGS },
  "reason": "why"
}'
```
- `method`: use `call_with` from retrieve_tools (`call_tool_read`, `call_tool_write`, `call_tool_destructive`)
- `name`: exact `server:name` from retrieve_tools
- `args`: native JSON object — daemon handles serialization

### Editing files — use @file, never inline JSON
```bash
mkdir -p /tmp/mcp-edits
cat > /tmp/mcp-edits/edit-001.json << 'JSONEOF'
{
  "method": "call_tool_write",
  "name": "SERVER:TOOL_edit_files",
  "args": {
    "files": [{
      "path": "the/file.md",
      "edits": [{"match_text": "exact text from read", "new_string": "new text"}]
    }]
  }
}
JSONEOF
curl -s localhost:<port>/call -d @/tmp/mcp-edits/edit-001.json
```
Read target with `compact: false` first — default compact strips whitespace, breaking match_text.

## Common Errors

| Symptom | Fix |
|---------|-----|
| `curl: (7) Failed to connect` | Run `bash .claude/hooks/ensure-mcp-daemon.sh`, retry |
| `Session refreshed, retry` | Just retry — daemon auto-reinits |
| `No client found for server: X` | Re-run `retrieve_tools` for correct names |
| Wrong params / unexpected error | Run `describe_tools` first — never guess schemas |
