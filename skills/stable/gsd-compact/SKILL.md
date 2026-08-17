---
name: gsd-compact
description: >
  Retrospective token-efficiency pass on a live gsd-lite artifact set. Measures the real cold-onboard cost, repairs missing/broken archive boundaries, demotes stale always-read content without deleting anything, and plants a Context Landmines section so future exploratory greps don't detonate. PROACTIVE ACTIVATION - run as a wrap-up step when a boot read felt expensive, when a "Large MCP response" warning fires on a gsd read, when onboarding a project whose artifacts are months old, or at sprint end before the gsd write.
user-invocable: true
---

# GSD-Compact - Retrospective Artifact Compaction

The three boot artifacts are append-only. Nobody ever deletes from them, so the always-read zone grows monotonically and every future session pays the tax again. This skill is the periodic collection pass.

**Prime directive: DEMOTE, NEVER DELETE.** Every byte removed from an always-read zone is moved verbatim into an archive zone in the same pass. The cut must be fully reversible, or it will not be trusted and will not be repeated.

## When to run

| Signal | Action |
|---|---|
| `Large MCP response (~Nk tokens)` warning on a boot read | run immediately, that project is bleeding |
| Boot read > ~12k tokens | run |
| Project artifacts untouched > 1 month | run at next onboarding |
| Sprint end, before the gsd write | run as the wrap-up step |
| A section in the always-read zone is version-stamped or past-tense | run, at minimum demote that section |

Run this **against a project you have just worked in**, so the judgment calls about what is still live are grounded in fresh evidence rather than guesswork.

---

## Phase 0 - MEASURE FIRST, READ NEVER

The cardinal error is reading the artifacts to find out how big they are. That pays the exact cost you are trying to remove. **One `run_command` answers everything for well under 1k tokens.**

```bash
cd <project>/gsd-lite
wc -c *.md
echo '--- BOOT ZONES (what a cold session actually reads) ---'
A=$(awk '/^## Version Archive/{exit} {print}' ARCHITECTURE.md | wc -c)
W=$(awk '/^## 1b\./{exit} {print}' WORK.md | wc -c)
P=$(wc -c < PROJECT.md)
echo "ARCH_zoneA=$A WORK_boot=$W PROJECT=$P TOTAL=$((A+W+P))"
echo '--- ARCH zone-A per-section bytes ---'
awk '/^## Version Archive/{exit} {print}' ARCHITECTURE.md | \
  awk '/^## /{if(h)print len" "h; h=$0; len=0} {len+=length($0)+1} END{if(h)print len" "h}' | sort -rn
echo '--- level-2 heading maps ---'
rg -n '^## ' ARCHITECTURE.md
rg -n '^## ' WORK.md
```

Rule of thumb: **bytes / 4 = tokens.** A 156 KB boot read is ~39k tokens, which is a fifth of a context window spent before any work begins.

---

## Phase 1 - BOUNDARY AUDIT (do this before anything else)

**The highest-value finding in this entire skill.** `read_to_next_pattern` does not error when its pattern matches nothing - it **silently reads to EOF**. So a project missing its archive headings has a boot read that is quietly, invisibly the entire file, and the protocol's own bounded-read discipline reports success while doing the opposite.

Detection - compare boot-zone bytes against total bytes from Phase 0:

| Symptom | Meaning |
|---|---|
| `WORK_boot` == `wc -c WORK.md` | `## 1b.` / `## 2b.` **do not exist** - boot is reading the whole atomic log |
| `ARCH_zoneA` == `wc -c ARCHITECTURE.md` | `## Version Archive` **does not exist** - boot is reading the whole file |
| Either roughly equals total | same bug, confirm with the heading maps |

**Fix before any content work.** Inserting the four missing headings is a pure structural edit that often delivers most of the win on its own, at zero risk:

- `WORK.md` - insert `## 1b. Prior Sprint Statuses (archive - not read at boot)` and `## 2b. Older Key Events (archive - not read at boot)` **between section 2 and section 3**. Boot then stops before the atomic log.
- `ARCHITECTURE.md` - append `## Version Archive` at the end.

Worked example: one project's `WORK.md` was 118,959 B with sections 1+2 totalling only 15,432 B. The missing `## 1b.` heading meant every boot read swallowed the 103 KB atomic log. Two inserted headings cut that read by 87% before a single word was rewritten.

**Ordering constraint:** section 3 must come after 1b/2b, and the atomic log must be the last thing in the file. If 1b/2b are placed after section 3, the boundary matches too late and nothing is saved.

**⚠️ Never test for an anchor with a substring check.** `if '## Version Archive' not in text` looks correct and is not: the moment any section quotes the read pattern in prose - which a good `## Context Landmines` section always does - the substring is present, the repair silently no-ops, and the file ships with no boundary at all. This has already happened once, in this skill's own first run. Test line-anchored:

```python
import re
has_anchor = re.search(r'^## Version Archive', text, re.M) is not None
```

The same applies to `## 1b.` / `## 2b.`. Phase 5 catches it, which is why Phase 5 is not optional.

---

## Phase 2 - TRIAGE the always-read zone

Phase 0's per-section byte ranking is the worklist. Work top-down; the top two sections are usually most of the file.

For each section, one question: **is this a fact that is still true and still consulted, or is it a record of something that happened?**

| Verdict | Signal | Destination |
|---|---|---|
| **Reference** | present tense, no version stamp, describes current behaviour, would be grepped by a future session | stays in zone A |
| **Archive** | version-stamped in the heading, past tense, "Phase N will...", superseded plans, per-file notes for code that has since been rewritten | demote verbatim |
| **Promote** | already in the archive but still true and still consulted | pull back up into zone A |

Both directions are required. Skipping promotion is how live knowledge ends up hidden behind a date and gets re-derived from scratch next session.

**Sections that rot fastest, in order:**

1. **`PROJECT.md` itself.** Written once at init, never revisited, and therefore most likely to describe a product that no longer exists. **Check its product model against reality before trimming anything else** - a cold agent reads it first and inherits whatever it says. One project's notes still described a browser-only tool with no backend, months after it had become a self-hosted server.
2. **Per-file / hot-zone tables** carrying notes for files that have since been rewritten, plus "will be refactored in Phase N" plans that either shipped or died.
3. **Key Events** rows that grew into multi-paragraph narratives. Section 2 is one line per event; the narrative belongs in the atomic log, addressed by its log id.
4. **Reference Baselines** measured against an environment that no longer exists.

**Do NOT demote by title alone.** Known Good Calls and Reference Baselines look dated because their headings carry dates, but they are exactly the reusable operational cache the protocol exists to preserve. Demote a Known Good Call only when the tool, host, or endpoint it targets is gone. When unsure, keep it - zone A tolerates a stale table row far better than a session tolerates re-deriving a working invocation.

---

## Phase 3 - LANDMINE SCAN

Ranks tracked files by **bytes per line**, because a grep match dumps the whole matching line. A 200 KB single-line file is a 50k-token bomb behind one incidental match.

```bash
cd <project>
git ls-files | while read f; do
  [ -f "$f" ] || continue
  b=$(wc -c < "$f"); l=$(($(wc -l < "$f")+1))
  echo "$((b/l)) $b $l $f"
done | sort -rn | head -15
```

Anything above ~20,000 bytes/line is a landmine: minified bundles, icon-set SVGs, lockfiles, single-line JSON manifests, vendored data. Write the findings into a `## Context Landmines` section in `ARCHITECTURE.md` zone A, **with measured numbers and a concrete reflex per entry** - a warning without a number gets ignored, and a warning without an alternative gets worked around badly.

The section must also carry the always-true traps:

- `rg '^#{1,4} '` on a mature `.md` reports fenced shell comments as headings. Always `^#{2,4} `. A level-1 index looks real and is not.
- Local shell `grep` is shimmed to `ugrep -G` and silently answers `0 matches` on patterns it cannot parse. Use `rg` locally, or the MCP `grep` tool remotely.
- A backslash-zero escape in an MCP edit payload becomes a real NUL byte, and one NUL makes the file reject every structured edit afterwards.
- The largest source file and the artifacts themselves, with their whole-file token cost and the bounded-read pattern that avoids it.

Close the section with the measured cold-onboard budget and the date, so drift is detectable rather than discovered.

---

## Phase 4 - SPLICE

Use `templates/compact.py` (copy to the target's `gsd-lite/tmp/`, edit the config block, run via `run_command`).

Why a python driver instead of structured `edit` calls:

- multi-KB section swaps need no exact `old_string` match
- it backs up all three artifacts before touching anything
- it splices by **anchor search**, never by line number - line numbers drift between the measure pass and the write pass, and a stale line number corrupts silently
- heading demotion is applied mechanically, which is where hand-editing fails

**The bug this template exists to prevent:** moving a `## ` section into the archive **without demoting its heading level** leaves a level-2 heading inside the archive, which destroys the `^## ` boundary that every bounded read depends on. The file then reads as all-reference forever after, and the next compaction inherits a broken structure. Demote heading levels in the same pass, always.

**Iterate lines, never `str.replace`.** A `s.replace('\n## ', '\n##### ')` misses the FIRST heading of the block, because it has no leading newline. That is exactly how the bug above ships despite an apparent fix.

Stage replacement bodies as separate files in `gsd-lite/tmp/` and have the driver read them, rather than embedding multi-KB strings in the script.

---

## Phase 5 - VERIFY (mandatory, every splice)

```bash
cd <project>/gsd-lite
rg -n '^## ' ARCHITECTURE.md          # exactly ONE '## Version Archive', nothing after it
rg -n '^## ' WORK.md                  # 1, 2, 1b, 2b, 3 - in that order
for f in *.md; do echo "$f nulls=$(tr -d -c '\000' < $f | wc -c)"; done   # must be 0
A=$(awk '/^## Version Archive/{exit} {print}' ARCHITECTURE.md | wc -c)
W=$(awk '/^## 1b\./{exit} {print}' WORK.md | wc -c)
P=$(wc -c < PROJECT.md)
echo "AFTER: $A + $W + $P = $((A+W+P))"
```

All four checks are load-bearing:

- **stray `## ` after the archive anchor** - the boundary-destroying bug; fix by demoting those headings to `##### `
- **WORK heading order** - 1b/2b after section 3 saves nothing
- **NUL bytes** - `rg` CANNOT detect these; a shell cannot hold a NUL in a pattern so it degrades to the empty string and matches every line. `tr -d -c` is the only reliable check
- **re-measure** - proves the cut and gives the number for the budget line

---

## Phase 6 - RECORD

One batched edit, three writes:

1. **`PROJECT.md` File Index** - the boot contract. Name the bounded read pattern for each artifact, the measured budget with its date, a pointer to `## Context Landmines`, and the `^#{2,4} ` grep rule.
2. **`ARCHITECTURE.md`** - the new `## Context Landmines` section, plus any Known Good Calls surfaced during the work that led here.
3. **`WORK.md`** - a `[DECISION]` log entry with before/after byte tables, what was demoted and where to find it, and any gotcha paid for during the splice. Then compress section 2 to one line about it.

Also check for **orphan files** under `gsd-lite/` (subdirectories like `ref/`, staged corpora) - anything not `tmp/` must be pointed at from one of the three core docs, or it is lost knowledge. Add the pointer in the same batch.

Leave `tmp/*.pre-compact.bak` in place until the next session confirms the artifacts read correctly.

---

## Reference: a completed pass

```text
BEFORE                          AFTER
PROJECT.md         4,785        4,349
ARCHITECTURE zoneA 44,693      27,802
WORK.md boot zone  24,297       9,037
TOTAL              73,775      41,188      -44%, nothing deleted
                  ~18.5k tok   ~10.3k tok
```

What produced it: `PROJECT.md` rewritten because it described the wrong product; a 17.8 KB hot-zone table of v1-era per-file notes demoted; a 10 KB gotchas section split into live operational traps (kept) and build-phase history (demoted); section 2's multi-paragraph event rows compressed to one line each with the prose preserved in 2b.

## Failure modes, ranked

| Failure | Cost | Guard |
|---|---|---|
| Reading artifacts to size them | pays the full cost you are removing | Phase 0 measures with `run_command` only |
| Missing archive headings unnoticed | boot silently reads whole file, forever | Phase 1 boundary audit, first |
| Demoting without demoting heading level | destroys the boundary permanently | Phase 5 `rg '^## '` after every splice |
| Deleting instead of demoting | knowledge loss, and the method stops being trusted | driver appends verbatim under a dated archive heading |
| Splicing by line number | silent corruption | driver splices by anchor search |
| Substring test for an anchor quoted in prose | repair no-ops, file ships unbounded | line-anchored regex, then Phase 5 `rg '^## '` |
| Demoting Known Good Calls because the heading has a date | re-derivation cost next session | Phase 2: demote only when the target is gone |
| Compacting a project you have not worked in | wrong live/stale calls | run as a wrap-up, not cold |
