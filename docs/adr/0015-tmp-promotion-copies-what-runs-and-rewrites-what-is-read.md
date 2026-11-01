# `tmp/` promotion copies what runs and rewrites what is read

Agents leave scripts, notes and raw output in a repo's gitignored
`tmp/YYYYMMDD/<topic>/` folders, and docs come to depend on them: one repo cited
`tmp/` 38 times across 15 of 28 topics, so clearing it would have broken those
docs. Promotion exists so a `tmp/` can be cleared without that loss. A separate
route, invoked by the operator, sorts each file in a topic folder:

| kind | example | result |
|---|---|---|
| authored and runnable | a benchmark script, a fixture generator, an answer key | **snapshot**: copied, after dehydration and a clean scan |
| authored prose | research notes, a handoff | **write-up**: rewritten as a page, decision or issue |
| rebuildable | downloads, compiled binaries, generated fixtures | stays in `tmp/` |
| passed through, not a repo | vendor docs, a captured term list | stays in `tmp/`, recorded with digest and capture time |
| raw tool output | logs, JSON from a tool | stays in `tmp/`; never promoted as is |
| regulated data, credentials, another client's material | | refused |

The line is whether a file is run or read. Every measured leak came from verbatim
capture, including a cookie jar pasted into an authored handoff, so being authored
does not make a file safe to copy. The rule that prose has no copy path stands. A
pointer needs a command to rebuild from, which is why runnable files need one.

This extends the table in ADR 0004 with a fifth unit:

| unit | mutation | where |
|---|---|---|
| dated evidence | frozen once committed | `evidence/YYYYMMDD-<topic>/` |

Each evidence folder has a `README.md` headed "snapshot, not maintained". It sits
at the root because `docs/` promises current truth. The wrap-up rules in
`AGENTS.md` keep governing current docs and do not apply here, because a frozen
snapshot is never read as current.

## The pointer

The committed record of what stays behind is one entry in that `README.md`:

- the original path, relative to the repo
- a source pin: `owner/repo@sha:path:line`, or a digest for a source that is not a repo
- the capture time
- the rebuild command, using variable names only

The rebuild command is mandatory. Without one the entry is not a pointer, and the
content has to be written up or discarded. The same rule applies to issue text
from now on, so a resolution cites committed evidence, not a gitignored path.

## Output that cannot be reproduced

A paid live service gives different numbers on a rerun, so its raw file is neither
rebuildable nor promotable. The measured numbers and the rerun command go in the
write-up, and the raw file is shown to the operator as a deliberate discard. Once
`tmp/` is cleared those rows are gone; that is accepted.

## Tracking what was promoted

The unit is the topic folder, because `tmp/` gets new work daily and the
one-time-per-directory rule for notes directories cannot hold here. A changed file
comes back to the menu.

The record is a machine-wide scanner database outside every repo. The agent reads
and writes it through scanner commands, and judges from the repo's current state
when no record exists. Four rules bound it:

1. **"Already scanned" never skips a leak scan.** A record can hide a file from the
   menu, not from the scanner: a file that passed can fail once a value is added to
   `.env`.
2. **It is not stored in `.env`.** That file is the gate's list of values to block.
3. **It is a convenience, and no record means not promoted.** It holds digests,
   handling and repo identity, never values, and the outbound gate never reads it.
   Losing it costs a repeated question, not lost work.
4. **Clearing a folder needs a matching record.** Agent judgement may recommend
   promotion, but it cannot see a deliberate discard, or tell whether a page really
   captured a file, so it cannot declare a folder safe to clear.

## Considered options

- **Never copy anything.** Rejected: pages would cite scripts nobody can rerun.
- **Copy anything that scans clean.** Rejected: it trusts the scanner with exactly
  the failure the rewrite rule exists to catch.
- **`docs/evidence/`.** Rejected: dated snapshots would sit beside pages that
  promise to be current.
- **A marker file in each topic folder.** Rejected: it dies when the folder is
  cleared, and only one folder's agent can read it.
- **A committed ledger.** Rejected: permanent status in the repo, and a way to carry
  `tmp/` details into it.
- **A promotion audit log.** Rejected: decisions already live in decision records
  and issue resolutions, proof in evidence, and history in `git log`. The cost is no
  single chronological view.

## Consequences

**Every promoted repo gains a top-level `evidence/` folder.** The docs index does
not cover it, deliberately.

**The record is per machine.** A fresh clone or another machine starts with no
record, so it asks again. The first target of this route is a legacy repo with little
structure for an agent to judge from, so expect extra menu questions there.

**The scanner gains state.** How it stores this belongs with "Scan cadence and
verdict cache", which already owns what the scanner remembers between runs.
