---
name: subagent-strategy
description: The very first file read to instruct subagents (optional read for root agent) to read when exploring codebases, researching design solutions, investigating architecture, gathering data for decisions, or any task that requires reading multiple files or querying remote systems.
user-invocable: false
---

# Subagent Strategy

## When to Delegate (Proactive)

**Prefer spawning a subagent when:**
- User asks about design or architecture and you need to explore the codebase first
- You need to read multiple files to answer a question — delegate the exploration
- You need to query remote systems (BigQuery, Looker) for grounding data
- The task is "fetch and summarize" — subagents compress 20K+ of raw data into 2K summaries
- Parallel exploration is possible — spawn multiple subagents simultaneously

**Do it yourself when:**
- Single MCP tool call — no need to spawn for one grep or one file read
- The user is actively pair-programming and needs real-time back-and-forth
- You need to write to WORK.md or other protocol artifacts (stay in conversation)

**The token math:** A subagent burns tokens internally but only returns a summary. Over a 20-turn session, delegating exploration saves 10-20x in cached context vs reading everything inline.

## The Rule
All subagents inherit the project sandbox: local I/O denied, MCP tools only.
No subagent can Read/Write/Edit/Bash locally — the local dir is a jumpbox.

## Model Selection

| Task complexity | Model | Rationale |
|----------------|-------|-----------|
| Fetch data, explore, search | **sonnet** | Cheap, fast, sufficient |
| Deep reasoning, write logs, architecture | **opus** | Needs nuance |
| Simple lookups, single tool call | **haiku** | Cheapest |

**Default: sonnet.** Escalate to opus only when the subagent needs to think, not just fetch.

## Agent Type Selection

| Task | Agent type | Why |
|------|-----------|-----|
| Explore codebase, query data, fetch results | **general-purpose** | No protocol overhead, has MCP + skills |
| Research Claude Code features | **claude-code-guide** | Specialized docs knowledge |
| Write WORK.md logs, architectural decisions | **gsd-lite** | Needs full protocol for journalism standard |

**Default: general-purpose.** Only use gsd-lite when subagent writes to protocol artifacts.

## Do NOT Use These Agent Types
- **Explore** — hardcoded to local fs tools, useless in MCP-only sandbox
- **Plan** — same problem, assumes local codebase

## Spawn Pattern

```json
{
  "subagent_type": "general-purpose",
  "model": "sonnet",
  "description": "3-5 word summary",
  "prompt": "Clear task description with expected output format"
}
```

## What Subagents Get
- ✅ MCP gsd-lite tools (filesystem via mcp__gsd-lite__*)
- ✅ MCP proxy tools (BQ, Looker, remote APIs via mcp__proxy__*)
- ✅ Project skills (proxy-tools auto-invokes for tier 2 work)
- ❌ Local filesystem (Bash, Read, Write, Edit, Grep — all denied)
- ❌ Parent conversation history (subagent starts fresh)

## GitHub in Subagent Prompts (copy-paste ready)

When a subagent needs GitHub data, inject this block into the spawn prompt:

```
## GitHub Access
- Quick lookups (README, issues, PRs, metadata):
  Use `github-gh-cli__shell_execute` via MCP proxy.
  Discover: retrieve_tools("gh-cli shell_execute")
  Call: {command: ["gh", "api", "repos/ORG/REPO/readme"], directory: "/tmp"}
  Call: {command: ["gh", "search", "code", "QUERY", "--repo", "ORG/REPO"], directory: "/tmp"}
- Deep code research (>3 files): clone to /tmp, grep locally:
  run_command({command: "git clone --depth 1 https://github.com/ORG/REPO.git /tmp/github-research/REPO"})
  Then grep_content + read_files against /tmp/github-research/REPO
- NEVER use WebFetch for GitHub URLs.
- NEVER use local `gh` CLI (not available on all hosts).
```

## Verifier/Advisor Subagents
When spawning a **verifier** or **advisor** subagent as part of a handoff loop,
see the `handoff-loop` skill for the structured briefing template and verification protocol.
This skill handles spawn mechanics; `handoff-loop` handles the verify-specific prompt and loop discipline.