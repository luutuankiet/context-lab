# Route: structured — author the two emitted skills

The contract file stands and the collections exist. What is missing is the tier
that fires **on trigger**: two skills under `.claude/skills/`, each a short piece
of hand-written prose wrapped around a generated index.

**These are the more important of the two artifacts this skill produces.** The
audit runs a handful of times per repository. These run forever, for agents that
have never heard of the audit and never will. Everything a future agent will know
about keeping this repository's context alive, it will learn from these two files
and from `AGENTS.md`. That is the whole teaching mechanism.

## Why two, and not one or twenty

They have genuinely different triggers, and if you merge them one always loses.

- **`codebase-map` is proactive.** Its trigger is *"I am about to go looking for
  something."* Its failure mode is silent: an agent that does not know the map
  exists just greps, and burns far more than the map costs.
- **`repo-maintenance` is reactive.** Its trigger is *"something is behaving
  wrong and not erroring."* Its failure mode is an afternoon lost to a known
  problem.

Not one skill per fact, either. **The minimum possible amount lives in the skill
and all the content lives in `docs/`** — a skill is read by one harness, a
markdown page is read by every tool and every human forever. The two bodies are
routers plus a generated table; no fact in them belongs on a page.

**Per-repository skills are never linked into the user-level skills directory.**
The linker flattens by directory name, which would leak one project's recipes
into every session on every host.

## Author them from the repository, not from the template

Copy [templates/codebase-map.SKILL.md](../templates/codebase-map.SKILL.md) and
[templates/repo-maintenance.SKILL.md](../templates/repo-maintenance.SKILL.md)
into `.claude/skills/<name>/SKILL.md`, then fill every `<…>` slot. A slot left as
a placeholder is worse than an absent skill: it reads as authoritative.

The facts each slot needs are cheap to gather and expensive to guess. Send
targeted exploration subagents and have them report **only the answer**, not the
files:

| what to find out | fills |
|---|---|
| the largest files, with **real line counts**, and which are opened most often | the map's "why line ranges exist" paragraph |
| the single most fragile path — where a change most often breaks something distant | the map's pointer into the trap catalogue |
| whether a type checker exists, and its command | the ladder's `this repo` column, rung 1 |
| whether a test runner exists, and its command | the ladder's `this repo` column, rung 2 |
| whether commenting at the site is the norm here, and one good example to cite | the ladder's `this repo` column, rung 3 |
| **what this repository's own conventions call things** | every sentence in both bodies |

That last row is the one that decides whether these files read as native. If the
repository says "collectors" rather than "plugins", or "runs" rather than "jobs",
use its words. What is emitted carries no brand: a repository laid out this way
reads as ordinary good housekeeping, not a methodology to learn first.

Verify each answer against running code before it goes in a body —
[sort-and-ladder.md](sort-and-ladder.md), section 3. A map that lies is worse
than none, because it sends people confidently to the wrong file.

## Decision-record awareness is the gap that phase two cannot recover from

Check that all three levels carry it, because after wiring, this skill may never
load in that repository again:

| level | what must be there |
|---|---|
| **always loaded** — `AGENTS.md` | one row for `docs/adr/` in the collections table, and one clause in the wrap-up rules naming when a decision is worth recording |
| **on trigger** — `repo-maintenance` | a collections row plus the three admission tests and immutability, in that repository's own words, roughly eight lines |
| **on demand** — `docs/adr/` | the directory with its numbering convention, and the seed record as a worked example |

The copy in the emitted skill is a **deliberate** second copy of the three tests
— different artifact, different reader, different tier. It is also a drift risk,
which is why [route-repair.md](route-repair.md) diffs the emitted skill against
the shipped template.

## Then generate, and check

```sh
<the repo's index generator>
<the repo's index generator> --check
```

The generated block replaces everything between the two markers in each body.
Leave the markers exactly as they are — the string is what the generator splices
on and what check 5 of the scanner looks for.

Re-run `scripts/audit.sh`. The state should now read `wired`.

## On a re-run, patch and never rewrite

If a body already exists, the prose in it is the human's. Change the `<…>` slots
that are now wrong, add a missing section, and leave every sentence you did not
have a reason to touch. The generated block is the only part that is yours.
