---
name: promote-private-notes
description: Promote a directory of private or uncommitted project notes into published, progressively-disclosed documentation. Use when asked to promote, publish, migrate or convert a project's private notes, work log, or agent state directory into committed docs — or when a brownfield repo keeps its real context in an ignored directory and it needs to become readable.
---

# Promote private notes

A directory of private project notes — a work log, a brief, an architecture file, an inbox — becomes published documentation a human would want to read. You are given the directory's path.

This is a **one-way, one-time** conversion per directory. It is not a sync, not a backup, and not a copy.

## The two rules that make this a gate and not a convention

**Privacy is a property of which remote, never of whether something is committed.** An ignore line is not a privacy boundary — it is the absence of a decision. So the question is never "may this be committed?" but "which remote does this belong to?"

**The per-file question is provenance, not secrecy:** *is this knowledge the project produced, or material that merely passed through it?* A work log is produced. A render fixture, a vendored binary, a captured API response passed through. A privacy scanner cannot tell those apart — the highest-severity flag in the survey that produced this skill was a deliberate test fixture. Correctly classified it is a discard by provenance, not an incident by privacy. Same outcome, and only the provenance reason generalises.

## Gate 1 — before writing anything

### 1. Enumerate raw. Non-negotiable.

```bash
rg -uu --files <dir> | sort      # or: find <dir> -type f | sort
```

Measured on one real directory of 97 files:

| enumeration | files seen | sees the one live credential |
|---|---:|---|
| `rg --files` (default) | 45 | no |
| `rg --hidden --files` | 78 | **no** |
| `rg -uu --files` / `find` | **97** | yes |

The credential sits under an ignored directory **and** is a dotfile, so neither `.gitignore` handling nor `--hidden` alone reveals it. Note which row is the trap: `--hidden` closes most of the gap, which is exactly what makes it dangerous — it looks like the fix.

An agent using default tools writes a confident, well-toned menu **from half the directory** and never learns the rest exists. **The moment enumeration is not raw, this skill degrades to bare convention.** Re-derive the count yourself; do not trust a number you were handed.

Two enumeration hazards worth knowing:

- A file containing a **NUL byte** makes `rg` stop searching mid-file and report a false all-clear past that point. `--files` is unaffected; any content scan is not.
- Do not shell out to `grep` in an agent sandbox — it is commonly shimmed to a BRE-mode tool that silently returns **zero matches** on patterns it cannot parse. Use `rg`.

### 2. Sort by provenance, then propose the output shape

Classify every root-level file, then decide what it *becomes*. Read [output-shape.md](output-shape.md) — it holds the target format and the per-source-file sort table. Most content is **delete**, and that is the expected outcome, not a failure of nerve.

### 3. Present the menu, then stop

The menu has two columns of substance: **which sources**, and **which documents they would become**. Sources alone are not enough — it would let the interesting decision (whether a 62-entry log becomes one dense page or four addressable ones) be made without the human.

**Collapse on depth, and asymmetrically:**

| side | rule |
|---|---|
| DISCARD | collapse freely — one row per subdirectory with a file count |
| PROMOTE | **never collapse** — anything becoming published prose gets its own row |

You need not show what you are not touching. This is what turns a 63-row menu into a ~6-row one, and it is safe *because* the collapsed rows are discards: in the measured case the one live credential collapses into a discarded row and is never opened, quoted, or promoted at all.

Then **stop and wait**. Do not begin writing on your own judgement of an obvious case.

### 4. Report shape violations

Your one content-free obligation, requiring no judgement at all: name any file whose presence contradicts the directory's own convention — an unexpected root file, or an unexpected subdirectory. Report; do not act on it.

Where the notes follow a house convention, state it and check against it. In the fleet this skill was built for, root level is knowledge and is only ever `WORK.md`, `PROJECT.md`, `ARCHITECTURE.md`, `INBOX.md`, `HISTORY.md`; subdirectories are everything else. Across six directories and 767 files there were **no exceptions** — 25 root files were the entire candidate set. If the target has no such convention, say so rather than inventing one.

### 5. Fire once per promotion, never as a blanket blessing

One approval covers the menu you just showed. A repo-level or standing approval silently hands the next session an approval whose contents it never showed anyone.

## Gate 2 — before commit

### 6. Promotion is a rewrite, never a copy

Every leak found across the investigation behind this skill came from **verbatim agent capture** — a cookie jar pasted into a handoff appendix, a raw evidence dump — and **none** from authored prose. Rewriting into publisher voice *is* the redaction boundary, because it is an **audience** boundary. There is no copy path in this skill, not even for a file that looks clean.

Two consequences:

- Never `cp`, never `git mv`, never `git add -f` a path inside the source directory. A single `-f` defeats the only control the source ever had.
- If the source prose carries a private notation system — internal log or task identifiers, section pointers into a file the reader cannot open — resolve each reference to plain English **with its evidence inline**. Where a repo ships a dedicated pass for that notation, use it rather than reinventing the resolution.

### 7. Run the topology check over the new prose only

A pattern scan of ~10 classes: host nicknames, DNS suffix, internal IP ranges, client identifiers. See [topology-check.md](topology-check.md) for how to derive the patterns locally and what to substitute.

Note the inversion that makes this worth doing: **the same scanning that is useless on sources is useful on output.** Across the source set it was 1.32% signal — 151 hits, 2 real. On authored prose it works, because the prose is small and the leak vocabulary is finite and known.

### 8. Report, never refuse

The check is **non-blocking by design**. Naming a host as inline evidence is a style call, not a privacy one — and this format asks for inline evidence everywhere else, so a check that refuses would be arguing with the format. Report the hits with line numbers and let the human decide.

### 9. Then the human reads

Gate 2 ends with a human reading the prose, not with a green checkmark. This is not a new obligation — it is the existing publisher-tone convention that has run 34 release notes deep with no known leak.

## What this skill deliberately does not do

- **No standing secret scanner, no pre-commit hook, no CI integration.** Measured at 1.32% signal, and `gitleaks`/`trufflehog` default to git history and staged content — these files are *never tracked*, so a pre-commit hook by definition never fires on them. Standing tooling does not rescue you from the methodology trap; it hides it behind a green checkmark.
- **No credential handling.** Credentials leave the repo boundary entirely; they are not hidden inside it. If enumeration surfaces one, name its path in the discard side, do not open it, and tell the human it wants rotating as hygiene.
- **No sync.** After promotion the source directory has no further role. Deleting it is the human's call; nothing here depends on keeping it.
