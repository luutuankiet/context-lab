# Output shape — what the notes become

Read this at Gate 1, when proposing the menu. It answers "which documents would
these sources become?" — and only that.

**It does not define the format of those documents.** That belongs to the repo's
housekeeping skill, which owns the always-loaded budget, the four-outcome sort,
the doc-is-the-last-resort ladder, and the trap-versus-reference test. A second
copy of a format is how a format rots, and this repo has already paid for that
lesson. In this repo the owners are:

| what | who owns it |
|---|---|
| the always-loaded budget | [`docs/architecture/repo-context-layout.md`](../../../../docs/architecture/repo-context-layout.md) |
| the four-outcome sort, and the ladder | [`repo-housekeeping/SKILL.md`](../../repo-housekeeping/SKILL.md) |
| page collections, filenames, frontmatter | [`repo-housekeeping/references/page-formats.md`](../../repo-housekeeping/references/page-formats.md) |

If the target repo has no housekeeping skill, say so in the menu rather than
inventing a house style.

## Per-source-file mapping

For the common house convention where root level is knowledge and subdirectories
are everything else. Destinations name the collection; the housekeeping skill
decides what a page in that collection looks like and what frontmatter it carries.

| source | becomes | note |
|---|---|---|
| **the activity / work log** | **delete**, after extracting live findings to issues or pages | once the artifacts are committed, `git log` *is* the archive. This is usually the largest file and it almost entirely goes. |
| **the inbox** | **issues**, one per live item | expect fully-diagnosed bugs complete with proposed fixes in here — filed as private by default rather than by judgement. That class is straightforwardly an issue each. |
| **the brief / project file** | the current-work parts → the issue tracker as one epic; the standing goal → the always-loaded **contract** | per-epic state belongs in the tracker, not in a file |
| **the architecture file** | the durable model → the always-loaded **model**, inside its budget; everything else → **`docs/architecture/`**, one page per area | usually the second-largest file. The budget forces the split; do not let the whole file become one page by default. |
| **a fact with a symptom** — something someone would observe going wrong | **`docs/traps/`**, filed under the symptom verbatim | wherever it was found. A trap that is only mentioned in passing still fires. |
| **a fact that is simply true** and expensive to re-derive | **`docs/reference/`** | |
| **the history / decision file** | one record per decision under **`docs/adr/`**; the narrative around them → **delete** | a decision with a reason is reference; the story of arriving at it is `git log` |
| **copy-paste operational recipes** (shell invocations, curl smoke tests, deploy commands, PATH prefixes) | **delete** | this is where credentials cluster. The sort and the scrub want the same thing here — lean on that. |
| **subdirectories** — fixtures, captured inputs, vendored binaries, virtualenvs, `.bak` copies of the log | **discard by provenance** | material that passed through; collapse these rows freely |

## Two things to verify before writing a page

- **Verify against running code, not against the notes.** In the conversion these
  numbers come from, every quoted line number had drifted, one documented path did
  not exist, and one fully-drafted page described an already-fixed bug — it was
  deleted before it shipped. The notes are a lagging record; the repo is the truth.
- **Indexes are generated, never hand-maintained.** If an index is written by hand
  it is stale by the second commit. Generate it, and check it in CI with a
  `--check` mode.

Measured on one full conversion: **888 KB of notes became 8 pages and 3 issues**,
and the always-resident context fell from ~28 KB to 3.2 KB. Most content is
delete, and that is the expected outcome.
