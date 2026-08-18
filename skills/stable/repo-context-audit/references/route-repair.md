# Route: the drift flag — patch, never rewrite

This is the route that fires most often, and it is the cheapest. Everything it
needs is already on screen: the scanner named each drifted page and printed the
frontmatter keys for the collection that drifted. **Do not load
`page-formats.md`.** If you find yourself wanting it, the job in front of you is
not a repair.

The governing rule: **patch, never rewrite.** Every page here was written by
someone. Change the key that is missing, the date that is stale, the link that
resolves to nothing — and leave every sentence you had no reason to touch.

## An orphan page

A top-level `docs/*.md` that carries no `title:`/`summary:` frontmatter is claimed
by no index and reachable from nothing. Two repairs, and the page decides which:

- **It is a long-form guide belonging to no single area** → add the three keys the
  scanner printed. It indexes as a guide.
- **It has a symptom, or it is simply true about one area** → it was a trap or a
  reference page all along. Move it into that collection, rename it to that
  collection's convention, and add that collection's keys.

An unclaimed page is a missing collection, not a cost of routing. Do not solve it
by linking the page from prose somewhere — the next generated index will still not
know it exists.

## A stale `verified:` date

The date says nobody has confirmed this against running code inside the threshold.
**It does not say the page is wrong.**

Open the page and re-read what it claims against the code. Then exactly one of:

- **still true** → bump `verified:` to today. That is the whole repair.
- **drifted** → fix the drifted part, bump the date, and say in the report which
  facts moved.
- **already fixed upstream** → delete the page and say so in the commit message.
  A stale trap costs a reader as much as a real one, and costs the catalogue the
  credibility that makes anyone open the next page.

**Never bump a date you did not verify.** A confidently re-dated wrong page is the
worst artifact this whole shape can produce.

## A stale index, or a missing collection

```sh
<the repo's index generator>
<the repo's index generator> --check
```

Regenerate and commit. If the generator is missing entirely, that is a repair too
— copy `scripts/gen-docs-index.sh` from this skill. Never hand-maintain an index.

A missing or empty collection directory is a scaffolding job, not a writing job.
Create it. Do not invent pages to fill it.

## The emitted skills, diffed against the template

The two skills under `.claude/skills/` carry a deliberate second copy of the
decision-record admission tests and the immutability rule. A second copy is a
drift risk, so check it here:

```sh
diff <this skill's base directory>/templates/repo-maintenance.SKILL.md \
     .claude/skills/repo-maintenance/SKILL.md
```

Expect differences — the whole point is that the emitted copy was written in this
repository's own words, with its own commands in the ladder. What you are looking
for is narrower:

- an admission test that has gone **missing** from the emitted copy
- the immutability rule gone missing
- a `<…>` placeholder left unfilled, which reads as authoritative and is not
- the ladder claiming a test runner or type checker the repository does not have

Repair those and nothing else. Rewording that is more native than the template is
a success, not drift.

## Finish

Re-run `scripts/audit.sh`. Report in the shape `SKILL.md` names — including
anything you could not verify, said plainly rather than written up on a guess.
