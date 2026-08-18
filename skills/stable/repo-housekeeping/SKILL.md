---
name: repo-housekeeping
description: Tidy a repo's own context before finishing a chunk of work — sort what the session learned into issues, pages, decision records and deletions, then regenerate the index. Use when wrapping up, handing off, or before opening a pull request; also when a repo's agent-facing context has grown into one unreadable always-loaded file.
metadata:
  verified: "2026-08-17"
---

# Leave the repo holding what the session cost you

A session discovers things. Most of that is lost when the session ends, and the
next one pays to discover it again. This is the pass that stops that — and the
discipline is that **most of what you learned should be deleted, not written down.**

## The split, and why this file is short

The repo you are working in states **what tidy looks like** in its root `AGENTS.md`
(or `CLAUDE.md`). That is the contract, it is always in context, and it stands alone
for any agent with no skills installed.

This file holds **how to do it**, and never restates the contract. If you find
yourself about to write a rule here that belongs in a repo's root file, that is
the signal you are duplicating a fact.

---

## 1. Read the contract

Open the repo's root `AGENTS.md` / `CLAUDE.md` and follow what it says. It outranks
this file everywhere they differ — this is a procedure, not a policy.

**If there is no root file, or it has grown past a screen or two, stop here** and
read `references/first-time-setup.md`. That is a one-time conversion, it is a
different and much larger job than a wrap-up pass, and it needs the human in the
loop before anything is written. Come back to step 2 afterwards.

## 2. Name what this session actually learned

Not what you did — what you now know that the repo does not say. Write the list
out. Useful prompts:

- What did you have to read three files to work out?
- What behaved differently from how it reads?
- What did you get wrong once before getting it right?
- What did you decide, where a reasonable person would have decided otherwise?
- What did you check that turned out to be already handled? (This is a *deletion*
  candidate, and often the most valuable entry on the list.)

An empty list is a legitimate outcome. Say so and stop — a pass that invents
something to write is worse than no pass.

## 3. Sort it

Every item gets exactly one disposition. Most get the last one.

| disposition | test | where |
|---|---|---|
| **issue** | it has a **next action** — something a person should do | the tracker |
| **page** | **durably true** and expensive to re-derive | `docs/` |
| **decision** | hard to reverse, surprising without context, a real trade-off | `docs/adr/` |
| **delete** | everything else | gone |

Be ruthless. These always look valuable and are not:

- status, dates, "as of v1.4", sprint state, release narrative
- version pins, dependency tables, measured sizes — all remeasurable, all stale
- host-specific commands, ports, deploy invocations, which machine is production —
  this is fleet state, not repo shape, and it is where credentials live
- anything phrased as a plan. An executed plan is history; an unexecuted one is a
  decision nobody made.

**A backlog is not documentation.** If it needs doing, it is an issue.

## 4. Run the ladder before writing any page

A doc only works if someone reads it, so it is the last resort. Stop at the first
rung that holds:

| rung | when |
|---|---|
| make it a **type error** | the mistake is expressible in the type system |
| make it a **test** | the mistake is expressible as an assertable behaviour |
| **comment at the site** | there is exactly one line where someone could get it wrong |
| **write a page** | the mistake can be made from several files, or from a file that does not exist yet |

Say out loud which single line you would have commented instead. **If you can name
it, comment it and stop.** This removes more than half of most candidate lists.

Note which rungs the repo actually has. If it has no test runner, do not tell a
future reader to write a test that cannot exist.

Architecture pages are **exempt** from the ladder. A map is not a warning, and
there is no cheaper rung than writing down where a thing lives.

## 5. Verify every fact against running code

This is the step that gets skipped, and it is the one that decides whether the
result is worth having.

**Your memory of this session is already stale.** So is anything you read an hour
ago. Open the file again. Re-read the function. Re-measure the line numbers.

If the underlying problem turns out to be already fixed, **delete the candidate**.
That is a success, not a loss — a page that is wrong costs a reader exactly as much
as one that is right, and costs the catalogue the credibility that makes anyone
open the next one.

Date every page `verified:` with the day you confirmed it. An undated claim has no
expiry.

## 6. Write

Formats, filenames, frontmatter and the ADR shape: `references/page-formats.md`.

Two rules that decide quality, and they are about the reader rather than the
format:

- **The reader is a maintainer six months from now who opened this one file from a
  search result and has nothing else loaded.** Not you. Not this session. Resolve
  every reference inline. No "see the other doc", no ticket numbers, no "as
  discussed above". If a line of code matters, quote it.
- **Say what is deliberate.** Half of what looks like a bug in a mature codebase is
  a trade someone made on purpose. Write down which, and what the trade was. It is
  the highest-value thing a session produces and the easiest to lose.

## 7. Regenerate the index, and check your work

Never hand-maintain an index — a hand-written one silently orphans pages and nobody
notices for a year. Run whatever the repo's contract names for this, then:

```sh
# the index is current
<the repo's index generator> --check

# every relative link in every page resolves to a file that exists
rg -o '\]\(([^)#][^)]*)\)' -r '$1' docs -g '*.md' | sort -u
```

If the repo has no generator yet, that is a gap worth an issue, not a reason to
hand-write the index this once.

## 8. Report to the human, honestly

Short, and in this shape:

- **written** — each page, one clause on why it earned a page
- **deleted** — what you dropped, and the rung of the ladder that caught it
- **filed** — issues opened
- **left alone** — anything you could not verify, said plainly rather than written
  up on a guess

If the always-loaded root file grew, say by how much. It is paid on every request
of every session, so growth there is a cost, not an achievement.

---

## What this pass is not

- **Not a place to write down what happened.** The activity narrative is already in
  the commits and the pull request, with diffs and timestamps. A hand-maintained
  session log is a second copy that starts rotting immediately.
- **Not a reason to keep a private notes directory in sync.** Two stores of truth
  is how the first one rotted. If a fact is worth keeping it goes in the repo.
- **Not a gate.** Nothing fails a build over any of this. If it is working, the repo
  reads as well kept rather than as somebody's methodology.
