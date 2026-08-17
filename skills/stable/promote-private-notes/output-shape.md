# Output shape — what the notes become

Read this at Gate 1, when proposing the menu. It answers "which documents would these sources become?"

## The target format

Three levels, sorted by **mutation mode** rather than by access pattern — how often a thing changes decides where it lives:

| level | file | when it loads | budget |
|---|---|---|---|
| L0 | root `AGENTS.md` — contract, model, index | always | **~2 KB** |
| L0 bridge | root `CLAUDE.md` → the single line `@AGENTS.md` | always | 11 bytes |
| L1 | a skill body, or one index page | on invocation | 1–3 KB |
| L2 | one self-contained page per topic under `docs/` | only when L1 names it | 0 until needed |

Index → unit → detail. Two properties are load-bearing:

- **L0 must stand alone.** A root file that merely says "invoke the housekeeping skill" is broken for any reader who has not installed that skill. Write the contract, do not delegate it.
- **No fact is written twice.** If a page holds it, the index points at it and does not summarise it. Duplication here is how the format rots.

Boot cost must scale with the **work claimed**, not with the size of the project. If the always-loaded set grows past its budget, that is a signal to split a page — not to trim a page that a large piece of work legitimately needs.

## The sort

Per file, four outcomes. The distribution is the point: **most content is delete.**

| outcome | goes to | test |
|---|---|---|
| **issue** | the repo's issue tracker, one per item | it is unresolved work with a symptom |
| **doc** | an L2 page, with L0/L1 pointing at it | it is *just true*, and a cold reader needs it |
| **someday** | the issue tracker, labelled and left | real, unresolved, and nothing is waiting on it |
| **delete** | nowhere | narrative, superseded, or reproducible from the repo |

Two tests keep the doc column honest:

- **A doc is the last resort.** The ladder is: type error → test → comment at the call site → doc. Before writing a page, name the single line you would have commented instead. If that line would have done the job, write the line.
- **If a fact has a symptom, it is a trap; if it is just true, it is reference.** Traps become issues, because a trap that is only documented still fires.

Measured on one full conversion: **888 KB of notes became 8 pages and 3 issues**, and the always-resident context fell from ~28 KB to 3.2 KB.

## Per-source-file mapping

For the common house convention where root level is knowledge and subdirectories are everything else:

| source | becomes | note |
|---|---|---|
| **the activity / work log** | **delete**, after extracting live findings to issues or pages | once the artifacts are committed, `git log` *is* the archive. This is usually the largest file and it almost entirely goes. |
| **the inbox** | **issues**, one per live item | expect fully-diagnosed bugs complete with proposed fixes in here — filed as private by default rather than by judgement. That class is straightforwardly an issue each. |
| **the brief / project file** | the current-work parts → the issue tracker as one epic; the standing goal → L0 **contract** | per-epic state belongs in the tracker, not in a file |
| **the architecture file** | the durable model → L0 **model** (inside the 2 KB budget); everything else → **L2 pages** | usually the second-largest file. The 2 KB budget forces the split; do not let the whole file become one page by default. |
| **the history / decision file** | one **ADR per decision** under `docs/adr/`; the narrative around them → **delete** | a decision with a reason is reference; the story of arriving at it is `git log` |
| **copy-paste operational recipes** (shell invocations, curl smoke tests, deploy commands, PATH prefixes) | **delete** | this is where credentials cluster. The sort and the scrub want the same thing here — lean on that. |
| **subdirectories** — fixtures, captured inputs, vendored binaries, virtualenvs, `.bak` copies of the log | **discard by provenance** | material that passed through; collapse these rows freely |

## Two things to verify before writing a page

- **Verify against running code, not against the notes.** In the conversion these numbers come from, every quoted line number had drifted, one documented path did not exist, and one fully-drafted page described an already-fixed bug — it was deleted before it shipped. The notes are a lagging record; the repo is the truth.
- **Indexes are generated, never hand-maintained.** If an index is written by hand it is stale by the second commit. Generate it, and check it in CI with a `--check` mode.

## Format authority

This table is the format **as decided today**, recorded here so a promotion can run before the dedicated housekeeping skill exists. Once that skill ships, it owns the format definition and this page defers to it — keep the mapping, drop the duplicated shape description rather than letting two copies drift.
