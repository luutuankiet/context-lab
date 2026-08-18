# Route: the notes flag — promote a working-notes directory

A directory of private project notes — a work log, a brief, an architecture file,
an inbox — becomes published documentation a human would want to read. The
scanner names the directory and its byte count; it has not opened it.

This is a **one-way, one-time** conversion per directory. It is not a sync, not a
backup, and not a copy.

## The two rules that make this a gate and not a convention

**Privacy is a property of which remote, never of whether something is
committed.** An ignore line is not a privacy boundary — it is the absence of a
decision. So the question is never "may this be committed?" but "which remote
does this belong to?"

**The sorting axis is provenance, not privacy.** For each file the question is
not "is this secret?" It is:

> **Is this knowledge this project produced, or material that merely passed
> through it?**

A work log is produced. A render fixture, a vendored binary, a captured API
response passed through. A privacy scanner cannot tell those apart — the
highest-severity flag in the survey that produced this route was a deliberate
test fixture. Correctly classified it is a **discard by provenance**, not an
incident by privacy. Same outcome, and only the provenance reason generalises.

Consequence: a file being sensitive is not what keeps it out. Being passed-through
is. Most sensitive material is passed-through anyway, so the axis subsumes the
worry it replaces.

---

# Gate 1 — before writing anything

## 1. Enumerate raw. Non-negotiable.

```bash
rg -uu --files <dir> | sort      # or: find <dir> -type f | sort
```

Measured on one real directory of 97 files:

| enumeration | files seen | sees the one live credential |
|---|---:|---|
| `rg --files` (default) | 45 | no |
| `rg --hidden --files` | 78 | **no** |
| `rg -uu --files` / `find` | **97** | yes |

The credential sits under an ignored directory **and** is a dotfile, so neither
`.gitignore` handling nor `--hidden` alone reveals it. Note which row is the trap:
`--hidden` closes most of the gap, which is exactly what makes it dangerous — it
looks like the fix.

An agent using default tools writes a confident, well-toned menu **from half the
directory** and never learns the rest exists. **The moment enumeration is not raw,
this route degrades to bare convention.** Re-derive the count yourself; do not
trust a number you were handed. Use `rg`, not `grep` — the reason is in the header
comment of `scripts/topology-check.sh`, and it applies to every scan here.

## 2. Sort by provenance, then propose the output shape

Classify every root-level file, then decide what it *becomes*. The general sort,
the escalation ladder and the verification pass are
[sort-and-ladder.md](sort-and-ladder.md); the page format is
[page-formats.md](page-formats.md). This route decides **what gets promoted and
into which kind of document**.

For the common house convention where root level is knowledge and subdirectories
are everything else:

| source | becomes | note |
|---|---|---|
| **the activity / work log** | **delete**, after extracting live findings to issues or pages | once the artifacts are committed, `git log` *is* the archive. Usually the largest file, and it almost entirely goes. |
| **the inbox** | **issues**, one per live item | expect fully-diagnosed bugs complete with proposed fixes in here — filed as private by default rather than by judgement. That class is straightforwardly an issue each. |
| **the brief / project file** | the current-work parts → the tracker as one epic; the standing goal → the always-loaded **contract** | per-epic state belongs in the tracker, not in a file |
| **the architecture file** | the durable model → the **contract**, inside its budget; everything else → **`docs/architecture/`**, one page per area | usually the second-largest file. The budget forces the split; do not let the whole file become one page by default. |
| **a fact with a symptom** — something someone would observe going wrong | **`docs/traps/`**, filed under the symptom verbatim | wherever it was found. A trap only mentioned in passing still fires. |
| **a fact that is simply true** and expensive to re-derive | **`docs/reference/`** | |
| **the history / decision file** | one record per decision under **`docs/adr/`**; the narrative around them → **delete** | a decision with a reason is reference; the story of arriving at it is `git log` |
| **copy-paste operational recipes** (shell invocations, curl smoke tests, deploy commands, PATH prefixes) | **delete** | this is where credentials cluster. The sort and the scrub want the same thing here — lean on that. |
| **subdirectories** — fixtures, captured inputs, vendored binaries, virtualenvs, `.bak` copies of the log | **discard by provenance** | material that passed through |

Measured on one full conversion: **888 KB of notes became 8 pages and 3 issues**,
and the always-resident context fell from ~28 KB to 3.2 KB. Most content is
delete, and that is the expected outcome, not a failure of nerve.

## 3. Present the menu, then stop

Two columns of substance: **which sources**, and **which documents they would
become**. Sources alone would let the interesting decision — whether a 62-entry
log becomes one dense page or four addressable ones — be made without the human.
The collapse rule and the one-approval rule are in the authority block of
`SKILL.md` and are in force here.

## 4. Report shape violations

Your one content-free obligation, requiring no judgement at all: name any file
whose presence contradicts the directory's own convention — an unexpected root
file, or an unexpected subdirectory. **Report; do not act on it.**

Where the notes follow a house convention, state it and check against it. In the
fleet this was built for, root level is knowledge and is only ever `WORK.md`,
`PROJECT.md`, `ARCHITECTURE.md`, `INBOX.md`, `HISTORY.md`; subdirectories are
everything else. Across six directories and 767 files there were **no exceptions**
— 25 root files were the entire candidate set. If the target has no such
convention, say so rather than inventing one.

---

# Gate 2 — before commit

## 5. Promotion is a rewrite, never a copy

Every leak found across the investigation behind this route came from **verbatim
agent capture** — a cookie jar pasted into a handoff appendix, a raw evidence dump
— and **none** from authored prose. Rewriting into publisher voice *is* the
redaction boundary, because it is an **audience** boundary. There is no copy path
here, not even for a file that looks clean.

If the source prose carries a private notation system — internal log or task
identifiers, section pointers into a file the reader cannot open — resolve each
reference to plain English **with its evidence inline**. Where a repository ships
a dedicated pass for that notation, use it rather than reinventing the resolution.

## 6. Run the topology check over the new prose only

```bash
<this skill's base directory>/scripts/topology-check.sh <new-file>...
```

[topology-check.md](topology-check.md) holds the vocabulary interface and the
substitution table. Note the inversion that makes it worth doing: **the same
scanning that is useless on sources is useful on output.** Across the source set
it was 1.32% signal — 151 hits, 2 real. On authored prose it works, because the
prose is small and the leak vocabulary is finite and known.

## 7. Report, never refuse

The check is **non-blocking by design**. Naming a host as inline evidence is a
style call, not a privacy one — and this format asks for inline evidence
everywhere else, so a check that refuses would be arguing with the format. Report
the hits with line numbers and let the human decide.

## 8. Then the human reads

Gate 2 ends with a human reading the prose, not with a green checkmark.

## Credentials

Credentials leave the repository boundary entirely; they are not hidden inside it.
If enumeration surfaces one, **name its path in the discard side, do not open it**,
and tell the human it wants rotating as hygiene.

No standing secret scanner and no pre-commit hook ships with this. Measured at
1.32% signal, and `gitleaks`/`trufflehog` default to git history and staged
content — these files are *never tracked*, so a pre-commit hook by definition
never fires on them. Standing tooling does not rescue you from the methodology
trap; it hides it behind a green checkmark.

## After

The source directory has no further role. Deleting it is the human's call;
nothing here depends on keeping it.
