---
name: webfetch-fallback
description: Use when WebFetch fails, returns an error, times out, or returns incomplete/blocked content, or fetching URLs that are known to be geo-restricted.
user-invocable: false
---

# WebFetch Fallback

## When This Activates

This skill triggers when:
- `WebFetch` returns an error (403, 429, timeout, connection refused)
- `WebFetch` returns incomplete or blocked content (CAPTCHA pages, "access denied", empty body)
- The user mentions geo-restriction, regional content, or blocked URLs
- You need to fetch content that WebFetch has already failed on

## The Fallback Tool

A remote `fetch_markdown` tool is available via the MCP proxy. It fetches web pages from a different server location and returns clean markdown.

**Discovery:** Search proxy tools for `"fetch markdown"` or `"web page content"`:
```
mcp__proxy__retrieve_tools(query="fetch markdown web page")
```

**Tool name format:** The result will show a `name` field like `server__toolname`. When calling via `call_tool_read`, use the **colon format**: `server:toolname` (replace `__` with `:`). The `call_with` field tells you which variant to use.

**Usage:** The tool accepts a list of URLs (1 to 10):
```
call_tool_read(
    name="<server>:<tool>",
    args_json='{"urls": ["https://example.com/page"], "filter_type": "fit"}',
    intent_reason="WebFetch failed, using remote fallback",
    intent_data_sensitivity="public"
)
```

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `urls` | string[] | *(required)* | 1-10 URLs to fetch |
| `filter_type` | string | `"fit"` | `fit` (readable), `raw` (full page), `bm25` (query-relevant) |
| `query` | string | `""` | Search query for bm25 filter mode |

## Fallback Pattern

```
1. Try WebFetch first (local, fast, no proxy overhead)
2. If WebFetch fails → discover fetch_markdown via retrieve_tools
3. Call fetch_markdown with the same URL(s)
4. If both fail → report to user with both error messages
```

**Do NOT skip WebFetch and go straight to fallback** unless you already know from this session that WebFetch fails for the target domain.

## Handling Large Responses (CRITICAL)

Proxy responses over ~20K chars are **truncated** with a cache key. When you see truncation:

1. **Use `read_cache`** with the provided key to paginate through the full content
2. **NEVER read from `~/.claude/` staging paths** — those are ephemeral session files that won't exist in future sessions. Any path containing `tool-results/*.json` is internal Claude Code plumbing and must not be accessed.
3. If `read_cache` fails or content is still too large, **summarize from what you have** rather than re-fetching individual URLs

```
mcp__proxy__read_cache(key="<cache_key_from_truncation>", offset=0, limit=50)
```

## Batch Efficiency

Unlike WebFetch (one URL per call), `fetch_markdown` accepts multiple URLs in a single call. When fetching several pages, batch them:

```json
{"urls": ["https://url1.com", "https://url2.com", "https://url3.com"]}
```

Each URL is fetched concurrently. Failed URLs don't block others.

## Subagent Delegation

For heavy web research (5+ URLs, long articles), delegate to a subagent:

```json
{
  "subagent_type": "general-purpose",
  "model": "sonnet",
  "description": "Fetch and summarize web pages",
  "prompt": "Fetch these URLs using the fetch_markdown proxy tool and summarize: [urls]. Use retrieve_tools to find 'fetch_markdown', then call it with call_tool_read."
}
```

This keeps large markdown payloads out of the main conversation context.