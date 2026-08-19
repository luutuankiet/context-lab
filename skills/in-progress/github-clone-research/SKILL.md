---
name: github-clone-research
description: Clone a GitHub repo to a local temp directory and research it with grep/read instead of using the GitHub MCP API. Much more efficient for deep code research — no pagination limits, no rate limits, full ripgrep access.
argument-hint: "<github-url-or-org/repo> <research-question>"
---

# GitHub Clone & Research

## GitHub Routing Rule (read this FIRST)

```
Need GitHub data?
├─ Deep code research (>3 files, patterns, cross-file)?
│   └─ THIS SKILL — clone + ripgrep
│
├─ Quick lookup (README, metadata, issue, PR)?
│   └─ github-gh-cli__shell_execute (MCP proxy) ← UNIVERSAL DEFAULT
│       retrieve_tools("gh-cli shell_execute")
│       {command: ["gh", "api", "repos/org/repo/readme"], directory: "/tmp"}
│
├─ Local repo ops (commit, push, diff)?
│   └─ Local git via Bash (NOT gh — some hosts lack `gh`)
│
└─ NEVER: WebFetch on GitHub URLs (404s, auth walls, JS rendering)
```

**Why proxy-first for quick lookups:** the `gh` CLI isn't installed everywhere — some hosts only have `git` over SSH and no `gh` at all. The MCP proxy `github-gh-cli` is reachable from ANY session.

---

> **When to use this skill:** You need to search a GitHub codebase deeply (find patterns, trace call chains, read multiple files). Cloning locally gives you full ripgrep + read access with zero API overhead.

## Protocol

### 1. Parse the input

Accept any of:
- Full URL: `https://github.com/looker-open-source/sdk-codegen`
- Shorthand: `looker-open-source/sdk-codegen`
- With branch: `looker-open-source/sdk-codegen@main`

Extract `org`, `repo`, and optional `branch`.

### 2. Clone to the local machine's temp dir

Use the the local machine's shell tool

```bash
# Shallow clone (saves time + disk)
git clone --depth 1 --single-branch \
  https://github.com/{org}/{repo}.git \
  /tmp/github-research/{repo}

# With specific branch:
git clone --depth 1 --single-branch --branch {branch} \
  https://github.com/{org}/{repo}.git \
  /tmp/github-research/{repo}
```

**Why `/tmp/github-research/`:** Isolated from real projects, auto-cleaned on reboot.

Fallback : if the local shell can't clone, pick a remote host with a filesystem MCP server and use its shell tool to clone into that host's `/tmp` dir

### 3. Research with local tools

Now use the local machine's native grep and read files  or the fallback host's MCP server's `grep_content` and `read_files` against the cloned repo:

```
# Find all attrs usage
grep_content(pattern="@attr.s", search_path="/tmp/github-research/{repo}")

# Read a specific file
read_files([{path: "/tmp/github-research/{repo}/python/looker_sdk/rtl/serialize.py"}])

# Find function definitions
grep_content(pattern="def unstructure_hook", search_path="/tmp/github-research/{repo}")
```

### 4. Cleanup (optional)

```bash
rm -rf /tmp/github-research/{repo}
```

Or leave it — `/tmp` is cleaned on reboot.

## Why this beats GitHub MCP API

| | GitHub API (proxy) | Clone + local grep |
|---|---|---|
| Search results | Paginated, max 100 | Unlimited |
| File reading | One file per call, truncates | Batch read, full content |
| Rate limits | Yes (even authenticated) | None |
| Regex search | Basic code search | Full ripgrep |
| Cross-file analysis | Multiple round-trips | One grep call |
| Token cost | High (API response overhead) | Low (only matched content) |

## Example

User: "Research how the Looker SDK serializes model objects"

```
1. git clone --depth 1 https://github.com/looker-open-source/sdk-codegen.git /tmp/github-research/sdk-codegen
2. grep_content(pattern="def serialize", search_path="/tmp/github-research/sdk-codegen/python")
3. grep_content(pattern="unstructure|asdict", search_path="/tmp/github-research/sdk-codegen/python")
4. read_files([{path: "/tmp/github-research/sdk-codegen/python/looker_sdk/rtl/serialize.py"}])
5. Synthesize findings, report back
```

## Notes

- Always use `--depth 1` — you need code, not history
- For monorepos, scope grep with `search_path` to the relevant subdirectory
- If the repo is private, the local machine's git config must have auth (SSH key or credential helper). Fallback: use `github-gh-cli__shell_execute` MCP tool (`gh auth login` is pre-configured on the proxy host).
- Prefer this skill over spawning a research subagent with GitHub MCP tools for any investigation that needs >3 file reads
