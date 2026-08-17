---
name: proxy-tools
description: Discover and call tools through an mcpproxy-go MCP proxy — the retrieve/call pipeline, read vs destructive variants, truncated-response handling, and upstream server management. Use when a tool you need is behind an MCP proxy rather than connected directly, when a proxied call fails or returns truncated output, or when you need to find which upstream server provides a capability.
---

# Proxy tools

Tools reached through an [mcpproxy-go](https://github.com/smart-mcp-proxy/mcpproxy-go)
proxy are not called the way directly-connected tools are. You discover them first,
then call them through a proxy tool, choosing the variant that matches whether the
call mutates anything.

Getting this wrong is the common failure: guessing a tool name that the proxy never
exposed, or using the read variant for a call that writes.

## Read this first

**[`reference.md`](./reference.md)** — the full pipeline, and the only thing you need:

- **Step 0** — identify your proxy and its tool-name prefix
- **Step 1** — discover the target tool rather than guessing its name
- **Step 2** — execute with the correct variant (read vs destructive), plus the
  critical details that decide which
- **Step 3** — handle truncated responses
- Schema caching within a session, upstream server management, and the mistakes
  that recur

The reference is deliberately agent-agnostic: it names tools by their
**server-native** names and uses `{PROXY}` as a placeholder for whatever prefix
your environment applies.
