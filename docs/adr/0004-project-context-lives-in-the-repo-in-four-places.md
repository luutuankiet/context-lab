# Project context lives in the repo, in four places

A project's accumulated knowledge is committed to the repository rather than kept
in an agent's private notes, and it is sorted by **how it mutates**, not by when it
is read:

| unit | mutation | where |
|---|---|---|
| the contract, the model, the index | rewritten, rarely | `AGENTS.md`, always loaded |
| prose that is durably true | superseded, occasionally | `docs/` |
| decisions | append-only, immutable once merged | `docs/adr/` |
| anything with a next action | drained | the issue tracker |

The axis is mutation rather than access pattern because the traffic is
overwhelmingly writes: the predecessor system mandated roughly ten write events per
two unconditional reads, so a read-time taxonomy modelled the minority of it.

## Considered options

- **A tier system keyed on when a session reads a thing** (always / on relevance /
  on reference). This was the starting assumption and it did not survive
  reconciliation: the predecessor's boot sequence read one contiguous byte range
  and explicitly exempted its core artifacts from any selective-read discipline, so
  its "on relevance" tier did not exist in practice.
- **Keeping the private notes and merely shrinking them.** Rejected: private notes
  are invisible to humans, shaped for one harness, and paid for on every turn
  whether or not the session is about them.
- **A flat token budget for boot.** Rejected outright as a goal. It forces trimming
  context that a large piece of work legitimately needs. What matters is that boot
  cost scales with the size of the *claimed work*, not with the size of the
  project — which falls out of this structure rather than needing a rule.

## Consequences

**Committing the artifacts deletes the archive tier.** The predecessor needed a
version-archive section precisely because its notes were gitignored and so had no
history. Once they are committed, `git log` *is* the archive, and the whole
demote/promote machinery goes with it — including a promote step that turned out
never to fire.

**No fact is written twice.** A page holds prose; the always-loaded file holds
pointers and constraints and never restates a page. When the always-loaded file
grows, the correct reading is that something in it was a page all along.

**Committing means a leak is permanent.** History cannot be rewritten without a
force-push, so anything private has to be caught before the commit, not after.
That is why privacy is a property of *which remote* a thing goes to, and never a
property of whether it is gitignored — an ignore rule protects a file exactly once
and is inert the moment the file is tracked.
