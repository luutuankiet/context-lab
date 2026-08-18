---
name: handoff-loop
description: >
  Use this when user shows intention that you work autonomously without human in the loop. PROACTIVE ACTIVATION — scan EVERY user message for autonomous signals before defaulting to pair programming.
  Trigger words: "hand off", "figure it out", "loop till done", "iterate", "advisor", "keep going", etc.
user-invocable: true
---

# Handoff Loop

## Trigger Patterns
- "hand off" / "handoff" / "handing off"
- "figure it out" / "work on this"
- "loop till done" / "iterate till done"
- "I'll be back" / "go ahead without me"
- Any signal that user wants autonomous execution without staying in the loop

---

## Phase 1: JIT Assessment (BEFORE any work)

On handoff signal, STOP and assess. Do not start coding.

### Discovery Checklist

Run these against the actual environment (grep, ls, retrieve_tools). Do NOT assume.

| Capability | How to Discover | Evidence Required |
|-----------|----------------|-------------------|
| **Build** | Scan for `Makefile`, `pyproject.toml`, `package.json`, `Dockerfile`, `Cargo.toml` | Exact build command found |
| **Test** | Look for `tests/`, `pytest.ini`, `jest.config`, `*_test.go`, `.github/workflows/test*` | Test runner + count of tests |
| **Exercise** | Can I call what I'm building? Check: passthru mode, curl endpoint, API reachable, MCP tool callable | Specific curl/call pattern identified |
| **Diff** | Is git available? Can I snapshot before/after? | `git status` works |
| **Deploy/Restart** | Docker compose? systemctl? Process restart? | Specific restart command |
| **Read Logs** | Log files? stdout capture? `run_command` available? | Log path or capture method |
| **Visual Verify** | Is `firefox-mcp` reachable? Can I screenshot a running frontend? | `retrieve_tools("firefox-mcp navigate screenshot")` returns tools |

### Environment Scan Commands (adapt to available tools)
```
# On remote host via run_command:
ls pyproject.toml package.json Makefile Cargo.toml 2>&1
ls tests/ test/ spec/ *_test.* 2>&1
git status 2>&1
which docker uv npm pytest 2>&1

# Check for shared browser (firefox-mcp):
retrieve_tools("firefox-mcp navigate screenshot")
# If found: you can visually verify frontend work mid-loop
```

---

## Phase 2: Confidence Declaration

Present this to the user BEFORE starting work. This is the contract.

```
[HANDOFF ASSESSMENT]

Task: {one-line description}
Host: {server/mount from session filesystem map}

CAN close loop on:
  - {capability}: {evidence -- exact command or tool}
  - {capability}: {evidence}

CANNOT close loop on:
  - {capability}: {why -- what's missing}

LOOP PLAN:
  1. {step} -> verify by {method}
  2. {step} -> verify by {method}
  3. ...

GAPS: {what won't be verified, and why it's acceptable or not}

Estimated iterations: {N}
```

### Decision Rules
- **All green:** Proceed with full loop. User can walk away.
- **Has warnings but non-critical:** Warn user, proceed with work, skip unverifiable steps. Report gaps at end.
- **Has critical gap:** STOP. Tell user what's needed. Do NOT proceed blindly.

---

## Phase 3: Execute Loop

```
while not done:
    1. Make changes (edit, implement)
    1b. If frontend task + firefox-mcp available: VISUAL CHECK inline
        - navigate to the page, read the screenshot
        - compare what you see vs what you intended
        - this is YOUR check as implementor, not the verifier's
    2. Run verify gate (should I spawn verifier?)
    3a. If gate=YES: write briefing -> spawn verifier -> act on verdict
    3b. If gate=NO:  self-check (run tests inline, check output)
    4. If PASS -> next task or done
    5. If FAIL -> read error, fix, goto 1
    6. If stuck (3 failures, same root cause) -> STOP. Report what happened.
```

### Frontend Visual Verification (Inline — No Verifier Needed)

When `firefox-mcp` tools are available and the task touches UI/frontend, the **implementor**
should visually verify its own work mid-loop. This is not the verifier's job — you have
eyes now, use them.

**Pattern:**
```
1. Make the frontend change (edit CSS, add component, fix layout)
2. If dev server running: firefox-mcp:navigate_page → screenshot returned
3. Read the screenshot — does it match intent?
4. If broken: fix inline, re-screenshot. No verifier needed for this loop.
5. If looks right: continue to next task or trigger verify gate for deeper check
```

**Viewport selection:**
- Mobile debug → `set_viewport_size({width: 390, height: 844})` before navigate
- Dashboard/admin → `set_viewport_size({width: 1280, height: 720})`
- Full desktop → default 1920x1080

**Tool names** (via MCP proxy — discover with `retrieve_tools`):
- `firefox-mcp:navigate_page` — go to URL + auto-screenshot
- `firefox-mcp:click_by_uid` — click + auto-screenshot
- `firefox-mcp:take_snapshot` — DOM tree with stable UIDs (for assertions)
- `firefox-mcp:screenshot_page` — standalone screenshot (no action)

**When NOT to visual-verify inline:**
- No `firefox-mcp` in session → skip, fall back to test suite
- Backend-only change → screenshots add nothing
- Token budget critical → each screenshot costs 439–2765 tokens depending on viewport

### Destructive Action Guardrail (NON-NEGOTIABLE)

**NEVER wipe, rewrite-from-scratch, or delete working/production code without explicit user approval.**

This applies especially when the loop is exhausted (high token usage, repeated failures, tunnel vision).
The temptation to "start clean" grows as frustration builds — that is exactly when this guardrail matters most.

| Action | Autonomous OK? | Requires user approval? |
|--------|---------------|------------------------|
| Edit specific lines/functions to fix a bug | ✅ | No |
| Add new files | ✅ | No |
| Refactor: rename, extract, move (preserving behavior) | ✅ | No |
| Delete a file and rewrite from scratch | ❌ | **YES — always** |
| `git checkout -- .` / `git reset --hard` | ❌ | **YES — always** |
| Replace >50% of a working file's content | ❌ | **YES — always** |
| Drop a database, clear a cache, reset state | ❌ | **YES — always** |
| Revert multiple commits | ❌ | **YES — always** |

**When stuck after 3 failures:** STOP and report. Do NOT escalate to destructive rewrites.
The correct response to "I can't fix this incrementally" is to hand back to the user with
a clear explanation of what failed, not to nuke working code and start over.

### Verify Gate -- When to Spawn a Verifier

Do NOT spawn a verifier on every edit. Use this decision tree:

| Condition | Spawn Verifier? | Rationale |
|-----------|-----------------|----------|
| Single file, <20 lines, tests pass inline | **No** -- self-check | Overhead exceeds value |
| Multi-file change, no inline test available | **Yes** | Fresh eyes needed, can't self-verify |
| Third retry on same error | **Yes** | Main agent has tunnel vision |
| User said "loop till done" (full autonomy) | **Yes** every major milestone | User isn't watching -- extra rigor |
| Change touches config/infra (non-reversible) | **Yes** | Consequences of mistakes are high |
| Final step before tag/push/deploy | **Yes always** | Last chance to catch issues |
| Frontend change + firefox-mcp available | **No** -- visual self-check | Implementor screenshots inline (see §Frontend Visual Verification) |

---

## Phase 4: Verifier Subagent

### Spawn Mechanics
**Defer to `subagent-strategy`** for model selection, agent type, and general spawn rules, *where it is installed* — it is not published in this collection. Where it is absent, this skill states no policy on model choice: pick the cheapest agent type that can hold the work.
This section only adds: the verifier-specific prompt template and structured briefing format.

### MCP Injection (NON-NEGOTIABLE)
The verifier MUST be able to actually grep diffs, run commands, and read files on the target server.
**Follow section 0.6 Subagent Injection from the agent body.** Every verifier spawn must include:
- The `[REF] Session filesystem map` content (server, mount, workspace prefix)
- Known Good Calls (exact tool names + arg shapes that worked this session)
- The correct `mcp_mode` block (native or daemon)

**A verifier that can't access the codebase is useless. This is the #1 failure mode.**

### Structured Briefing Template (Main Agent Writes This)

The briefing is NOT free-form prose. It's a structured form that forces explicit claims.
**This template is mandatory** -- it prevents vague briefings that produce shallow verification.

```markdown
## Verifier Briefing

### What I Changed
| File | Lines | Summary |
|------|-------|--------|
| {path} | {range} | {what and why} |

### Claims (each must be verifiable)
1. CLAIM: {specific behavior assertion}
   VERIFY BY: {exact command or check}
   EXPECTED: {specific output/behavior}

2. CLAIM: {assertion}
   VERIFY BY: {command}
   EXPECTED: {output}

### What Should NOT Happen (negative checks)
- {edge case or regression that would indicate failure}
- {thing that broke before and must not break again}

### Invariants (project-level rules that must hold)
- {e.g., "All Gemini schema compat tests pass"}
- {e.g., "No new lint warnings"}

### Git Diff
{paste or reference: `git diff HEAD~1` or specific files}
```

**Why structured:** A vague briefing like "I updated the search function, check it works" produces
a vague verdict like "tests pass, looks good." A structured briefing with explicit claims forces
the verifier to check each claim with evidence.

### Verifier Prompt Template

Inject into the subagent spawn:

```markdown
## Your Role: VERIFIER
You are reviewing work done by another agent. You did NOT write this code.
Your job: find problems, not approve. A bare "PASS" with no evidence is a failure on YOUR part.

## {MCP INJECTION BLOCK -- from section 0.6, including session filesystem map}

## Briefing
{STRUCTURED BRIEFING FROM MAIN AGENT}

## Verification Protocol
1. Read the git diff or changed files -- understand what actually changed
2. For each CLAIM in the briefing:
   - Run the specified verification command
   - Compare actual output to expected output
   - Record: confirmed / contradicted / inconclusive
3. Check NEGATIVE cases -- try to break it
4. Check INVARIANTS -- run project-level checks
5. Assess DIFF COVERAGE -- are there changes NOT covered by any claim?
   If yes, flag them: "Lines X-Y in file Z were modified but no claim covers this behavior"

## Output Format (MANDATORY)
VERDICT: PASS | PASS WITH NOTES | FAIL

### Claim Verification
| # | Claim | Result | Evidence |
|---|-------|--------|----------|
| 1 | {claim} | result | {exact output or observation} |
| 2 | {claim} | result | {exact output} |

### Negative Checks
- {what was tested} -> {result}

### Uncovered Changes
- {files/lines modified but not claimed -- potential blind spots}

### Recommendation
- {what main agent should do next: proceed / fix X / re-examine Y}
```

---

## Phase 5: Handoff Report (When Done)

When the loop completes (or is stopped), present to user:

```
[HANDOFF REPORT]

## Completed
- {what was done, with evidence}

## Verified (with evidence)
| Check | Method | Result |
|-------|--------|--------|
| {check} | {how verified} | pass/warn |

## NOT Verified (with reason)
- {what wasn't checked and why}

## User Should Review
- {specific things that need human eyes}

## Artifacts Modified
- {file list with summary of changes}
```

---

## Anti-Patterns

| Anti-Pattern | Why It's Bad | The Fix |
|-------------|-------------|--------|
| **Skip assessment, start coding** | Can't verify -> push broken code | Phase 1 is mandatory |
| **Vague briefing** ("check my work") | Produces rubber-stamp verdicts | Structured briefing template is mandatory |
| **Verify every tiny edit** | Token waste, slows the loop | Verify gate decision tree |
| **Naked verifier spawn** | Verifier can't access codebase | section 0.6 MCP injection is non-negotiable |
| **Ignore verifier FAIL** | Defeats the purpose | FAIL = must fix before proceeding |
| **Push/tag/deploy without final verify** | Irreversible mistake | Always verify before irreversible actions |
| **3+ retries without escalating** | Tunnel vision, wasting tokens | Stop after 3, report honestly |
| **🚨 Frustration rewrite** | Wipes working code when stuck — irreversible, user wasn't consulted | NEVER delete+rewrite without user approval. Incremental fix or STOP. See Phase 3 guardrail. |

---

## Interaction with Other Skills

| Skill | Relationship |
|-------|-------------|
| **subagent-strategy** (unpublished) | Handoff-loop DEFERS to it for spawn mechanics where it is installed. Does NOT redefine model selection or agent types. |
| **task-reconstruction** (deprecated, not shipped) | If a session forks during a handoff loop, it helped the new session pick up where the loop left off |
