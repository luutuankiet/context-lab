# The sort, the ladder, and verification

Three passes over the same pile, in this order. Setup runs them over everything a
repository has accumulated; wrap-up runs them over one session's findings;
promote runs them over one notes directory. The pile changes size; nothing else
about them changes.

## 1. Sort — four outcomes, and most things get the last one

Every item gets exactly one disposition.

| disposition | test | where |
|---|---|---|
| **issue** | it has a **next action** — something a person should do | the tracker |
| **page** | **durably true** and expensive to re-derive | `docs/` |
| **decision** | hard to reverse, surprising without context, a real trade-off | `docs/adr/` |
| **delete** | everything else | gone |

Be ruthless. These always look valuable and are not:

- status, dates, "as of v1.4", sprint state, release narrative
- version pins, dependency tables, measured sizes — all remeasurable, all stale
- host-specific commands, ports, deploy invocations, which machine is production.
  This is fleet state, not repo shape, and it is where credentials cluster.
- anything phrased as a plan. An executed plan is history; an unexecuted one is a
  decision nobody made.

**A backlog is not documentation.** If it needs doing, it is an issue.

An empty result is a legitimate outcome. Say so and stop — a pass that invents
something to write is worse than no pass.

## 2. The ladder — run it before writing any page

A doc only works if someone reads it, so it is the last resort. Stop at the first
rung that holds.

| rung | when |
|---|---|
| make it a **type error** | the mistake is expressible in the type system |
| make it a **test** | the mistake is expressible as an assertable behaviour |
| **comment at the site** | there is exactly one line where someone could get it wrong |
| **write a page** | the mistake can be made from several files, or from a file that does not exist yet |

Say out loud which single line you would have commented instead. **If you can
name it, comment it and stop.** This removes more than half of most candidate
lists.

Note which rungs the repository actually has. If it has no test runner, do not
tell a future reader to write a test that cannot exist — and when you fill in the
ladder in the emitted maintenance skill, write "there is no test runner" rather
than leaving the column hopeful.

**Architecture pages are exempt.** A map is not a warning, and there is no
cheaper rung than writing down where a thing lives.

This is the ladder's only home in this skill. The one other copy is in
`templates/repo-maintenance.SKILL.md` — an emitted artifact for a different
reader in a different repository, with that repository's own commands filled into
its third column. Nothing in this skill's own prose restates it.

## 3. Verify against running code — never against the notes

This is the step that gets skipped, and it is the one that decides whether the
result is worth having.

**Your memory of this session is already stale.** So is anything you read an hour
ago, and so is every number in a notes file. Open the file again. Re-read the
function. Re-measure the line numbers.

Measured on one full conversion, against disk: **every quoted line number had
drifted**, one systematically by 79 lines; one documented path did not exist; a
claimed "4 call sites" was 2; and one fully drafted, well-argued page described a
bug that had **already been fixed**.

That page was deleted before it shipped, and **deleting it was the success**. A
page that is wrong costs a reader exactly as much as one that is right, and costs
the catalogue the credibility that makes anyone open the next one.

Date every page `verified:` with the day you confirmed it. An undated claim has
no expiry.
