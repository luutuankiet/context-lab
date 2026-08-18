# Route: wired, no flags — hand off

The repository already states what tidy looks like, in its own always-loaded
contract file. **Read that first and follow it. It outranks this file everywhere
they differ** — this is a procedure, not a policy, and the repository's own
wrap-up rules are the ones a cold agent with no skills installed will read.

If the emitted `repo-maintenance` skill exists, it is the reader's route, not
this one. Prefer it. This page exists for the case where you are already here.

## 1. Name what this session actually learned

Not what you did — what you now know that the repository does not say. Write the
list out. Useful prompts:

- What did you have to read three files to work out?
- What behaved differently from how it reads?
- What did you get wrong once before getting it right?
- What did you decide, where a reasonable person would have decided otherwise?
- What did you check that turned out to be already handled? That is a *deletion*
  candidate, and often the most valuable entry on the list.

An empty list is a legitimate outcome. Say so and stop.

## 2. Sort it, ladder it, verify it

[sort-and-ladder.md](sort-and-ladder.md), over this session's findings only.

## 3. Write, and regenerate

Formats are [page-formats.md](page-formats.md). Then:

```sh
<the repo's index generator>
```

## 4. Report

In the shape `SKILL.md` names. If the always-loaded file grew, say by how much.

## What this pass is not

- **Not a place to write down what happened.** The activity narrative is already
  in the commits and the pull request, with diffs and timestamps. A
  hand-maintained session log is a second copy that starts rotting immediately.
- **Not a reason to keep a private notes directory in sync.** Two stores of truth
  is how the first one rotted. If a fact is worth keeping it goes in the
  repository.
- **Not a gate.** Nothing fails a build over any of this. If it is working, the
  repository reads as well kept rather than as somebody's methodology.
