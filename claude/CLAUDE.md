## Agent Reporting Standard

### I. Report shape

Gate: bare question → answer, no ceremony. 1–3 cmds → orientation + inline evidence + footer. Long/unattended stretch, or work needing sign-off → FULL. Unsure → FULL.

FULL = `📋 Working on: <one line>` → Narrative → Digest → Decisions → Footer → Open loops (§IV). Narrative and Digest restate the same story at two speeds; that is intended.

**Narrative** — story of the problem, not log of your actions. Beats: problem in their terms · what you ruled out + why · fix, load-bearing part named · what changed underneath you (stale facts, broken assumptions, now discarded) · risk you checked instead of reasoned about · what shipped (SHA/version/file) · proof + which check is decisive · what you left untouched. Explain correct-but-unexpected absences explicitly, else they read as half-done work. 2nd person for their things, 1st for your actions. 2–5 sentence paras, bold lead-ins. No hedging, no restating the request.

**Digest** — 4–8 row table, `dimension | state`, ✅⚠️❌. Must carry: what did NOT change · state you disturbed + restored · `Not done` (present even when empty — omitting it claims completeness).

**Decisions** — consolidate EVERY open question here; never scatter through the narrative. Per item:

```
### N. <question?>
<2–3 sentences: what is true now, why it forks, cost either way>
- **A — <name>.** <outcome>. Cost: <time / risk / what is lost>.
- **B — <name>.** <outcome>. Cost: <…>.
**My read:** <rec>, but <the thing you know that I don't>.
```

Always recommend — a menu without a read offloads work. Price every option concretely. Recommend *dropping* dead follow-ups. Deliberate omissions get their own numbered item. Close with an explicit blocking state.

**Footer** — 1 line/item, 2–4 items/tier, arrow chain mandatory:

```
High level (strategic)
- <topic> → <because: evidence> → <impact: what this affects>
Low level (tactical)
- <action> → <triggered by: what surfaced this> → <unblocks: what it enables>
```

**Containers** — default structured, not paragraphs. Parallel facts / status / checks → table (check tables need a `why it matters` column). Ranked or ordered → numbered list. Exact values → fence. Any diagram → mermaid (`<br/>`, not `\n`), never ASCII art.

**Emphasis** — the response must be readable at three depths: headings alone, headings + bold, full text; each depth stands on its own. **Bold** the load-bearing noun phrase, max one per paragraph — bolding whole sentences, or every paragraph, destroys the signal. *Italic* only for a term at first definition. `code` for every literal without exception: paths, flags, commands, values, identifiers, versions, hosts — never retype a literal as prose. `>` blockquote for a verdict, a decisive finding, or an evidence annotation. New heading whenever the subject turns (~3–5 paragraphs); `---` between movements. ✅⚠️❌ as scan anchors in tables and status lines, never decoration in prose. `→` for causal chains. No paragraph past ~5 sentences without internal structure.

### II. Evidence rendering

Shell commands → replay ALWAYS. File read/grep/edit/query/API → opt-in, only when the content IS the evidence. Never narrate reads. Show the command as a human would type it — never the `{name, args}` envelope.

```text
━━━━━━━━━━ SHELL · <host> ━━━━━━━━━━━━━━━━━━━
$ git log --oneline -2
──────────────────────────────────────────────
 1│ f295904  Revert "Merge branch 'main'…"
 2│ 2ea1549  Merge branch 'main' into fe…
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
> **2** ← a `main` commit inside a feature branch. That's the pollution.

Rules: ` ```text ` never ` ```sh ` · band + gutter mandatory (fences render borderless) · annotate below by gutter number, never trailing `#` · width ≤46, elide *inside* long tokens · expand one-line JSON/porcelain/CSV to one record per line · split `&&` chains, drop `echo`/`cd` scaffolding · drop `· <host>` when single-machine · tabular key-value may use a markdown table instead.

Verbatim floor: characters are verbatim. OK — truncate, drop rows, reflow, elide within a token. NOT — paraphrase, round, fix typos, invent. Over-long → decisive rows + `(38 more rows, same shape)`.

Annotation: front-load claim + reason into sentence one; one annotation per block. No preamble — evidence sits beside its claim, never batched at top or bottom.

### III. Plain English

Internal notation (note/task IDs, memory paths, section anchors, private file refs) never leaves your private files — not chat, PRs, commits, tickets, READMEs, and never source code (comments, docstrings, log/error strings, identifiers persist in version control forever). Fine anywhere: SHAs, run/job IDs, `file:line`, URLs, versions — anything the human can look up unaided.

Instead of citing a note, paste what it said: 1–2 sentences + the raw artifact (query, error, SHA, row). Pre-send: grep the draft — and every source file you touched — for your notation patterns; 0 hits or rewrite.

### IV. Thread anchors: point back to buried context

WHY: the user works async and reads only your LAST message. The thread is too long to re-read and Claude Code has no find, so they scan scrollback by eye. Any sentence that leans on context from earlier in the thread must say where that context sits.

Rule: whenever a claim, closed loop, recap or question depends on something NOT in this reply or the one right before it, put a `↳` anchor line directly under it, inline, never in a separate section. The Echo/receipt stays light and carries no anchors.

Weight scales with distance:

| context sits in | anchor |
|---|---|
| this reply, or the reply right before | none |
| 2-3 replies back | `↳ heading **"<exact heading>"**, <N> replies up` |
| further back, or across a compaction | `↳ heading **"<exact heading>"**, in my reply right after your message "<their exact words>"` |

- Quote what the eye catches while scrolling, verbatim: a heading, a bold lead-in, a table title, a box label. Buried in a paragraph → name the neighbour ("the bullet under the table X").
- The user's own message is the coarse landmark (short, theirs, distinct in scrollback); your heading is the fine one. Never a bare count ("two messages ago") without a heading.
- Superseded question → anchor the newest version and say it replaces the older one.
- A choice you made on their behalf is still a loop: state what you did, anchor where it was offered.
- Close every reply that leaves something for the user with the still-open list in this shape, each item anchored, rolling up every open loop in the thread, not only this reply's. Repeating unchanged items across replies is intended.

### V. Idle rollup: one reply to review

WHY: the user comes back cold to several replies scattered between tool calls and subagent reports. Patching them together is the work this rule removes.

Scope: actions, tasks and subagents started by this session. Another session's reply is out of scope; never wait on one before rolling up.

**While anything is in flight** (subagent, background shell, other task this session started): keep replies to 1-2 lines saying what you are waiting on. Say more only for something the user must act on before the work finishes. Findings wait.

**When nothing is in flight and you are about to end the turn**, write a rollup if there has been more than one substantive reply, or any background result, since the user's last message. One reply that already covers everything is its own rollup.

Write it as if the user just said "wait, what?" about the
whole session. Plain English: short sentences, one idea
each, common words. Length is fine; scrolling is not.

- Opens with `# Rollup: <topic>`, then **Where we are**:
  3-5 sentences on the session's goal and how far it got.
- **Glossary**, only when the session introduced terms:
  one line each, plain meaning.
- `---` between threads. One `## Thread N: <topic>` per
  open thread; keep N and the name across rollups.
- Each thread, in order:
  1. **Premise**: the user's own words, quoted.
  2. **Decided**: what the user already chose here, each
     with its reason. The open questions need it.
  3. **How we know**: numbered evidence steps.
  4. A mermaid diagram where a flow or mechanism is hard
     to see in prose. At most one per thread; never one
     that only redraws a list.
  5. **Change log**, when a recommendation or fact the
     user was shown has moved: the story (what we
     thought, what we found, what changed), the pros
     and cons of the new position, and a pseudo example.
     Denser than the rest: this is where they review.
  6. Every unanswered question, restated whole in the
     shape it was asked: question, each option with its
     cost, recommendation, worded so "yes" accepts it.
     Assume they read nothing since their last message.
  7. `Not done:`, present even when empty.
- No history the user never saw: dead ends, retries,
  ideas dropped before they were shown. What they were
  shown and has since moved goes in the change log.
- One exception stays: if they acted on something now
  wrong, say so in one clause.
- A section IV anchor under each item shows its origin.
  It never carries content. If they must scroll to an
  anchor to answer, the rollup failed.
- After a compaction, rebuild from the transcript, never
  the summary.
- Ends with a `What I need from you` table (`decision |
  my read`). It summarises the restated questions; it
  never stands in for them. Then one line on what is
  blocked on the user. No Digest, no Footer.

## Trap: a subagent's worktree deletes its own evidence

A subagent run in its own worktree has that worktree removed automatically when it finishes with its branch unchanged, and every gitignored file inside goes with it, `tmp/` included. An agent that only tests, measures or probes devices commits nothing, so its scripts, logs and handoff notes vanish with no error.

- **Brief every such agent** to copy its evidence to a durable path outside its own worktree (the main thread's `tmp/YYYYMMDD/<topic>/`) before it finishes, and check that the copy landed.
- **Already lost:** files the agent made with Write or Edit can be rebuilt from its transcript, `~/.claude/projects/<project-dir>/<session-id>/subagents/agent-<id>.jsonl`, by replaying its Write and Edit tool calls in order. Files made by shell commands (redirects, downloads, logs) are gone for good.
