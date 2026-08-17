---
name: gsd-stamp
description: two way gsdlite artifact quickstart skill. OUTBOUND (stamp) on-demand by user to leave a gsd-lite footprint in a remote project dir when wrapping up ad-hoc work, so future sessions can find it via list_gsd_lite_dirs. INBOUND (find) when user says "there's a gsd-lite on server X for project Y", discover + boot from it in one sweep via list_gsd_lite_dirs + universal onboarding read.
---

# GSD-Stamp — Leave & Find Remote Footprints

This skill has two modes — pick based on what the user says:

| User says | Mode |
|-----------|------|
| "leave a footprint", "stamp this", "so we can find it next time" | **OUTBOUND** → stamp a new gsd-lite |
| "there's a gsd-lite on the remote host for claude-docker", "go to server X, gsd-lite for Y" | **INBOUND** → find + boot from existing gsd-lite |

---

## MODE A: INBOUND — Find & Boot from a Footprint

> User tells you a server + project name. You find the gsd-lite, do onboarding, and start working — no path required.

### Step 1 — Discover the tool

```
retrieve_tools("list gsd lite dirs")
```

Look for a tool named like `list_gsd_lite_dirs` on the target server. Note the `server`, `name`, and `call_with` fields.

### Step 2 — List all gsd-lite projects on the server

```bash
# call list_gsd_lite_dirs with include_meta: true to get summaries
{
  "method": "<call_with>",
  "name": "<server>:<tool_name>",
  "args": { "include_meta": true }
}
```

Returns a list of directories with summaries from their PROJECT.md.

### Step 3 — Match natural language to path

The user said "claude-docker" → scan summaries for keywords → match to path like `~/dev/claude-docker/`.

**Decode the workspace prefix from the tool name** (§0.2 of gsd-lite protocol):
- Tool `<host>_at_slash__list_gsd_lite_dirs` → mount = `/`
- Matched path `/home/<user>/dev/claude-docker/` → MCP-relative = `home/<user>/dev/claude-docker/`

### Step 4 — Universal onboarding read (one batched call)

```json
{
  "files": [
    {"path": "<workspace>/gsd-lite/PROJECT.md"},
    {"path": "<workspace>/gsd-lite/ARCHITECTURE.md"},
    {"path": "<workspace>/gsd-lite/WORK.md", "head": 60}
  ]
}
```

### Step 5 — Echo understanding + confirm ready

Report back:
- What the project is (from PROJECT.md "What This Is")
- Last known state (from WORK.md Section 1 `<current_mode>`, `<next_action>`)
- Most recent log entry summary
- What you're ready to help with

**Example output:**
> "Got it — `claude-docker` on the remote host: two-container Claude Code quota pre-warmer (`<container>-a` + `<container>-b`), cron every 30 min, push alerts to `<your-ntfy-topic>`. Last session fixed false auth alerts from `401` matching UUIDs — now stable. What do you need?"

---

## MODE B: OUTBOUND — Leave a Footprint

> Wrapping up ad-hoc work. No gsd-lite in the project yet. Stamp one so future sessions find it.

### Step 1 — Check if already stamped

```bash
ls <project-dir>/gsd-lite/ 2>&1
```

If exists → skip scaffold, jump to Step 3 (append a new log entry to WORK.md).

### Step 2 — Scaffold gsd-lite

Run on the remote server (use the server's `run_command` tool):

```bash
cd <project-dir> && npx -y @luutuankiet/gsd-lite@latest
```

This creates:
```
gsd-lite/
  PROJECT.md    ← fill this (what the project is)
  ARCHITECTURE.md ← fill this (files, data flow, entry points)
  WORK.md       ← fill this (session log)
  INBOX.md
  HISTORY.md
```

### Step 3 — Fill PROJECT.md

Read the project's key files first to understand context, then write:

```markdown
# Project
*Initialized: YYYY-MM-DD*

## What This Is
[2-3 sentences: what runs here, what it does, why it exists]

## Core Value
[Single sentence: the ONE thing that must work]

## Success Criteria
- [x] [observable outcome already working]
- [ ] [outcome still in flight]

## Context
[Background: replaced what, depends on what, account/service info]

## Constraints
[Hard limits: platform, auth, external dependencies]
```

**Minimum viable PROJECT.md:** Just "What This Is" + "Context" is enough for discoverability.

### Step 4 — Fill ARCHITECTURE.md

```markdown
# Architecture
*Mapped: YYYY-MM-DD*

## Project Structure Overview
| Path | Purpose |
|------|---------|
| key/file.ext | what it does |

## Tech Stack
- Runtime, key deps

## Data Flow
[Mermaid sequence or brief text — even 3 lines is enough]

## Entry Points
1. **most-important-file** — start here for any debugging
2. **config-file** — env vars and schedules live here
```

### Step 5 — Add LOG-001 to WORK.md

Fill Section 1 (current state) and append the first log entry:

```markdown
## 1. Current Understanding
<current_mode>maintenance / active / exploration</current_mode>
<active_task>none</active_task>
<vision>[one line: what this project is for]</vision>
<decisions>[key choices made so far]</decisions>
<next_action>[if anything is outstanding]</next_action>

## 2. Key Events
| Date | Event | Impact |
|------|-------|--------|
| YYYY-MM-DD | [what happened] | [why it matters] |

## 3. Atomic Session Log

### [LOG-001] - [TYPE] - [summary] - Task: ad-hoc
**Timestamp:** YYYY-MM-DD
**Depends On:** none (first log)

#### What Happened
[What we found, what we fixed, what we left in place]

#### Key Files Touched
- `path/to/file` — what changed and why

📦 STATELESS HANDOFF
**What was decided:** [brief]
**Next action:** [specific next step or "none — stable"]
**Key file:** [most important file to start from]
```

### Step 6 — Verify discoverability

After writing, test that `list_gsd_lite_dirs` would surface this project:

```bash
cat <project-dir>/gsd-lite/PROJECT.md | head -20
```

## Quality Bar (both modes)

**Minimum to be useful:**
- PROJECT.md "What This Is" section filled (2-3 sentences)
- ARCHITECTURE.md has a file table with at least the top 3 files
- WORK.md has a log entry with what was done in this session

**Full quality (preferred):**
- Data flow diagram (even 3-node Mermaid)
- Re-auth / recovery procedure documented
- Key gotchas noted (e.g., "bare 401 matches UUIDs — use \\b401\\b")

## MCP Path Translation

When writing to a remote server, translate paths:

| What you have | What to pass to MCP tool |
|---------------|--------------------------|
| `~/dev/claude-docker/`, i.e. `/home/<user>/dev/claude-docker/` (absolute) | `home/<user>/dev/claude-docker/` (strip leading `/`) |
| Tool mount `<host>_at_slash__` | mount = `/`, so strip `/` from abs path |

Always use `compact: false` when reading before editing (exact verbatim needed for `match_text`).

## End-to-End Example

**Session 1 (today) — Outbound:**
```
Worked on ~/dev/claude-docker on the remote host, fixed false 401 alerts.
→ /gsd-stamp <host> ~/dev/claude-docker
→ scaffolded gsd-lite, wrote PROJECT/ARCH/WORK with context from session
→ list_gsd_lite_dirs now returns "claude docker quota pre-warmer"
```

**Session 2 (next time) — Inbound:**
```
User: "hey go to the remote host, there's a gsd-lite for the claude docker thing"
→ retrieve_tools("list gsd lite dirs")
→ list_gsd_lite_dirs on <host> → matches "claude docker" → ~/dev/claude-docker/
→ batch read PROJECT.md + ARCHITECTURE.md + WORK.md head
→ "Got it — quota pre-warmer, 2 containers, last fix was the 401/UUID grep. What do you need?"
```

No path memorization. No re-explanation. The stamp IS the memory.

## Protocol

### Step 1 — Check if already stamped

```bash
ls <project-dir>/gsd-lite/ 2>&1
```

If exists → skip scaffold, go to Step 3 (update existing WORK.md).

### Step 2 — Scaffold gsd-lite

Run on the remote server (use the server's `run_command` tool):

```bash
cd <project-dir> && npx -y @luutuankiet/gsd-lite@latest
```

This creates:
```
gsd-lite/
  PROJECT.md    ← fill this (what the project is)
  ARCHITECTURE.md ← fill this (files, data flow, entry points)
  WORK.md       ← fill this (session log)
  INBOX.md
  HISTORY.md
```

### Step 3 — Fill PROJECT.md

Read the project's key files first to understand context, then write:

```markdown
# Project
*Initialized: YYYY-MM-DD*

## What This Is
[2-3 sentences: what runs here, what it does, why it exists]

## Core Value
[Single sentence: the ONE thing that must work]

## Success Criteria
- [x] [observable outcome already working]
- [ ] [outcome still in flight]

## Context
[Background: replaced what, depends on what, account/service info]

## Constraints
[Hard limits: platform, auth, external dependencies]
```

**Minimum viable PROJECT.md:** Just "What This Is" + "Context" is enough for discoverability.

### Step 4 — Fill ARCHITECTURE.md

```markdown
# Architecture
*Mapped: YYYY-MM-DD*

## Project Structure Overview
| Path | Purpose |
|------|---------|
| key/file.ext | what it does |

## Tech Stack
- Runtime, key deps

## Data Flow
[Mermaid sequence or brief text — even 3 lines is enough]

## Entry Points
1. **most-important-file** — start here for any debugging
2. **config-file** — env vars and schedules live here
```

### Step 5 — Add LOG-001 to WORK.md

Fill Section 1 (current state) and append the first log entry:

```markdown
## 1. Current Understanding
<current_mode>maintenance / active / exploration</current_mode>
<active_task>none</active_task>
<vision>[one line: what this project is for]</vision>
<decisions>[key choices made so far]</decisions>
<next_action>[if anything is outstanding]</next_action>

## 2. Key Events
| Date | Event | Impact |
|------|-------|--------|
| YYYY-MM-DD | [what happened] | [why it matters] |

## 3. Atomic Session Log

### [LOG-001] - [TYPE] - [summary] - Task: ad-hoc
**Timestamp:** YYYY-MM-DD
**Depends On:** none (first log)

#### What Happened
[What we found, what we fixed, what we left in place]

#### Key Files Touched
- `path/to/file` — what changed and why

📦 STATELESS HANDOFF
**What was decided:** [brief]
**Next action:** [specific next step or "none — stable"]
**Key file:** [most important file to start from]
```

### Step 6 — Verify discoverability

After writing, test that `list_gsd_lite_dirs` would surface this project:

```bash
# Check the summary field gsd-lite uses for discovery
cat <project-dir>/gsd-lite/PROJECT.md | head -20
```

## Quality Bar

**Minimum to be useful:**
- PROJECT.md "What This Is" section filled (2-3 sentences)
- ARCHITECTURE.md has a file table with at least the top 3 files
- WORK.md has LOG-001 with what was done in this session

**Full quality (preferred):**
- Data flow diagram (even 3-node Mermaid)
- Re-auth / recovery procedure documented
- Key gotchas noted (e.g., "bare 401 matches UUIDs — use \\b401\\b")

## MCP Path Translation

When writing to a remote server, translate paths:

| What you have | What to pass to MCP tool |
|---------------|--------------------------|
| `~/dev/claude-docker/`, i.e. `/home/<user>/dev/claude-docker/` (absolute) | `home/<user>/dev/claude-docker/` (strip leading `/`) |
| Tool mount `<host>_at_slash__` | mount = `/`, so strip `/` from abs path |

Always use `compact: false` when reading before editing (exact verbatim needed for `match_text`).

## Example — What We Did for claude-docker

```
User: "there's a claude docker ping job on the remote host — leave a footprint"

1. cd ~/dev/claude-docker && ls gsd-lite       → MISSING
2. npx -y @luutuankiet/gsd-lite@latest         → scaffolded
3. Read docker-compose.yaml + healthcheck.sh   → understood the project
4. Wrote PROJECT.md: quota pre-warmer, 2 containers, push alerts
5. Wrote ARCHITECTURE.md: file table, mermaid sequence, auth grep gotcha
6. Wrote WORK.md LOG-001: false 401 alert bug fix from this session
7. list_gsd_lite_dirs → project now discoverable as "claude docker quota ping"
```

## Finding It Next Time

Once stamped, future sessions can discover it with:

```
retrieve_tools("list gsd lite dirs")
→ call list_gsd_lite_dirs on the target server
→ returns project summaries including this one
→ natural language match: "claude docker" → ~/dev/claude-docker/
```

No need to remember the path. The stamp IS the memory.
