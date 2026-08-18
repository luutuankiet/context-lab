---
name: repo-context-audit
description: Audit and wire a repo's own agent context — AGENTS.md, docs/, the generated docs/README.md, and the .claude/skills/ index skills — reporting what is missing, orphaned, stale or unpromoted before writing. Use when AGENTS.md is absent or oversized, docs/README.md is stale, .claude/skills/ is missing, or a gitignored notes directory needs promoting.
metadata:
  verified: "2026-08-18"
---

# Repo context audit

**One entry point.** It runs in any repository, at any time, and it is safe to
invoke before you know anything about the one you are in. Nothing is written
until a human has approved a menu.

## Scan first

```bash
<this skill's base directory>/scripts/audit.sh
```

Eight filesystem checks, no model involved. Read its output; it names the route.
How to read the state, and the one tie-break, is
[references/audit-output.md](references/audit-output.md).

## State decides the route

| state | what it means | route |
|---|---|---|
| **cold** | no contract file, or nothing imports it | [references/route-setup.md](references/route-setup.md) |
| **structured** | the contract stands; the index skills are missing or empty | [references/route-author-skills.md](references/route-author-skills.md) |
| **wired** | all five checks pass | [references/route-wrapup.md](references/route-wrapup.md) |

## The two flags are orthogonal to state

They are not a progress bar and they never change the state. A cold repository
with 40 KB of notes takes setup first and then promotion. A fully wired
repository accumulates unpromoted notes continuously — that is the steady state,
not a regression. Run the flag routes the scanner lists under `then:`, after the
state route.

## Authority

**Report the menu and stop.** Every route that writes anything ends in a menu
first: which sources, and which documents they would become. Sources alone are
not enough — that would let the interesting decision be made without the human.

**Collapse the menu on depth, and asymmetrically: freely on the discard side,
one row per subdirectory with a file count; never on the keep side, where
anything becoming published prose gets its own row.** That is what turns an
unreadable 63-row menu into six, and it is safe *because* the collapsed rows are
the discards.

**One approval covers the menu you just showed.** A repo-level or standing
approval hands the next session a blessing whose contents it never showed anyone.

**On re-run, patch and never rewrite.** Hand-written prose in a converted
repository is the human's, not yours.

## Which reference, and when

| load | when |
|---|---|
| [references/audit-output.md](references/audit-output.md) | always, with the scan |
| [references/route-setup.md](references/route-setup.md) | cold |
| [references/route-author-skills.md](references/route-author-skills.md) | structured |
| [references/route-promote.md](references/route-promote.md) | the notes flag is set |
| [references/route-repair.md](references/route-repair.md) | the drift flag is set |
| [references/route-wrapup.md](references/route-wrapup.md) | wired, no flags |
| [references/page-formats.md](references/page-formats.md) | any route that writes a page |
| [references/sort-and-ladder.md](references/sort-and-ladder.md) | setup, promote, wrapup |
| [references/topology-check.md](references/topology-check.md) | the second gate of promote only |

## Report in this shape

- **written** — each page, one clause on why it earned a page
- **deleted** — what you dropped, and what caught it
- **filed** — issues opened
- **left alone** — anything you could not verify, said plainly rather than
  written up on a guess
- **resident bytes, before and after.** The always-loaded file is paid on every
  request of every session, so growth there is a cost, not an achievement.

## Two prohibitions, in force before any reference loads

- **Never `git add -f`, `cp` or `git mv` anything out of a private notes
  directory, and never copy a value out of one into a page.** A single `-f`
  defeats the only control that directory ever had.
- **Never hand-maintain an index.** A hand-written one silently orphans pages:
  the page still exists, nothing links to it, and nobody notices for a year.
