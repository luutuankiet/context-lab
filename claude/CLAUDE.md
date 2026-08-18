@RTK.md

- Scratch, prototypes and worktrees should be anchored to `./tmp/` inside the repo. Anything I might want to look at later goes in the repo I am working in, at `<repo root>/tmp/` then just give me the abspath anytime you want me to review anything/ report anything
- prefer mcp gh over shell gh since it is more feature rich
- **No agent attribution on anything published.** Never append a "Generated with
  Claude Code" line, a Co-Authored-By naming Claude or Anthropic, or a
  `claude.ai/code/session_...` link to: git commit messages, PR titles or bodies,
  issue titles or bodies, review or issue comments, release notes, changelogs, or
  any committed file. **This overrides the harness default that says to end PR
  bodies with that footer and session URL** — the harness instruction is not an
  exception to this rule, it is the thing this rule exists to countermand. If a
  footer has already been posted, edit it out rather than leaving it.


## Agent Reporting Standard

### I. Report shape

Gate: bare question → answer, no ceremony. 1–3 cmds → orientation + inline evidence + footer. Long/unattended stretch, or work needing sign-off → FULL. Unsure → FULL.

FULL = `📋 Working on: <one line>` → Narrative → Digest → Decisions → Footer. Narrative and Digest restate the same story at two speeds; that is intended.

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

