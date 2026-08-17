---
name: promote-working-notes
description: Promote a project's private working-notes directory into published repo documentation, behind two gates — a raw-enumeration menu the human approves before anything is written, and a topology check over the newly-authored prose before commit. Use when publishing, promoting, or migrating private project notes into a brownfield repo's docs, or when asked to "publish the notes" / "promote the working directory" for a repo.
---

# Promote working notes

A project accumulates a private working-notes directory: work logs, architecture jottings, an inbox of half-diagnosed bugs, plus whatever passed through — fixtures, caches, vendored binaries, the odd credential. Promotion turns the **knowledge** in there into documentation the repo publishes, and leaves the rest behind.

This skill is the procedure. It fires **once per promotion, for one directory**, never as a blanket blessing of a repo.

## The sorting axis: provenance, not privacy

For each file the question is **not** "is this secret?" It is:

> **Is this knowledge this project produced, or material that merely passed through it?**

A work log is produced. A render fixture is passed-through. A privacy scanner cannot tell them apart — pointed at directories of this class it runs at roughly **1% signal**, and its loudest hits are typically deliberate test fixtures. Provenance sorts correctly *and* generalises; privacy does neither.

Consequence: a file being sensitive is not what keeps it out. Being passed-through is. Most sensitive material is passed-through anyway, so the axis subsumes the worry it replaces.

---

## Gate 1 — before writing anything

### 1. Enumerate raw

```bash
rg -uu --files <dir>        # or: find <dir> -type f
```

**Non-negotiable, and the single point where this skill silently fails.** Default tooling is *structurally* blind here. Measured in one real directory of this class: a default `rg` saw **45 of 97 files**, and the one live credential returned **0 hits** — it sat under an ignored directory *and* was a dotfile, so neither `.gitignore` handling nor `--hidden` alone revealed it.

An agent using default tools writes a confident, well-toned menu **from half the directory** and never learns the rest exists. The moment enumeration is not raw, this gate degrades to bare convention while still looking like it ran.

Report the raw count alongside the default count when they differ. The gap is the finding.

### 2. Present a menu, plus the proposed output shape

The menu is not a file list. It is **which sources, and which documents they would become** — because the interesting decision is the shaping, not the selection. Whether a 62-entry work log becomes one dense page or four addressable ones is the human's call, and a sources-only menu makes it without them.

Default source → destination mapping for a directory of this shape:

| Source | Becomes |
|---|---|
| Project overview, architecture notes | The repo's always-read root file — contract, model, index |
| Durable how-to knowledge, per-topic | One cache entry per topic, addressable on its own |
| Decisions with rationale | An in-repo ADR each |
| Inbox items — diagnosed bugs, proposals | **Issues on the tracker**, not prose |
| Activity log / dated history | **Deleted.** Once the artifacts are committed, `git log` *is* the archive |
| Everything under subdirectories | Discard, unless a specific file is nominated |

Propose the mapping; let the human move rows.

> The *format* of those destination documents is not this skill's job — it belongs to the repo's housekeeping/authoring skill. This skill decides **what gets promoted and into which kind of document**; that one decides what each kind looks like. If the repo has no housekeeping skill yet, say so in the menu rather than inventing a house style.

### 3. Collapse on depth — asymmetrically

- **Root level is knowledge.** One row per file. Never collapse.
- **Subdirectories are everything else.** One row each, with a file count.
- **Collapse freely on the DISCARD side. Never collapse anything on the PROMOTE side.**

You need not show what you are not touching; anything becoming published prose gets its own row. This is what makes the menu ~6 rows instead of 63, and it is safe *precisely because* the collapsed rows are discards — a live credential collapses into a discarded row and never enters the promotion path at all.

Corollary: **do not open, quote, or excerpt anything on the discard side.** Collapsing it is the containment.

### 4. Report shape violations

The one obligation requiring **no content judgement**:

- A root file outside the directory's canonical set. Where this shape is followed, that set is `WORK.md`, `PROJECT.md`, `ARCHITECTURE.md`, `INBOX.md`, `HISTORY.md` — use the caller's set if they declare a different one.
- An unexpected subdirectory.

Report them; do not act on them. A violation usually means the directory drifted, and the human knows why.

### 5. Stop and wait

Present the menu. **Wait for the human.** Do not write, do not stage, do not create the destination files.

Approval covers *this* directory and *this* menu. It never generalises to the repo — a repo-level approval silently hands the next session a blessing whose contents it never showed anyone.

---

## Gate 2 — before commit

### 6. Promotion is a rewrite, never a copy

Every leak found across the investigation that produced this skill came from **verbatim agent capture** — a cookie jar pasted into a handoff appendix, a raw evidence dump — and **never** from authored prose.

Rewriting into publisher voice *is* the redaction boundary, because it is an **audience** boundary. Copy a paragraph and you have imported its audience along with its text. There is no such thing as promoting a file unchanged.

### 7. Run the topology check over the new prose only

```bash
skills/stable/promote-working-notes/scripts/topology-check.sh <new-file>...
```

Note the inversion: the same scanning that is **useless on sources** (~1% signal) is **useful on output**. Authored prose is small, and its leak vocabulary is finite and known.

Substitutions, when the human decides something should change:

| Found | Becomes |
|---|---|
| Host nickname | A **capability description** — never a replacement name. A fake hostname is still a topology claim. |
| Internal DNS suffix | `example.com` |
| Absolute home paths | `~/` |
| Client / customer identifiers | The `acme` orders-and-customers vocabulary |
| Worked examples | **Keep their shape and magnitude.** A scrub that collapses every number to `N` destroys the pedagogy the example existed for. |

See [references/topology-check.md](references/topology-check.md) for the pattern classes and how the identity vocabulary is supplied.

### 8. Report, never refuse

The check is **non-blocking by design**. Naming a host as inline evidence is a **style** call, not a privacy one — and this documentation style insists on inline evidence everywhere else. The check makes the mentions visible at write time; the human decides whether they stay.

A checker that refuses trains the author to phrase around it.

### 9. Then the human reads

Gate 2 is not new machinery. It is the existing publisher-tone convention, and that convention is many release notes deep with no known leak. The check just makes its blind spot visible.

---

## Deliberately not built

**No standing secret scanner. No pre-commit hook. No CI integration.**

Measured: **1.32% signal** — 2 real hits in 151 across six directories. 38% were elided placeholders inside prose (`Bearer <PAT>`), 34% vendored library strings.

And the decisive fact: `gitleaks` and `trufflehog` default to scanning **git history and staged content**. These files are *never tracked*. A pre-commit hook, by definition, never fires on them. Standing tooling would not have caught the one real credential; it would have hidden that failure behind a green checkmark.

The gates are agent obligations at authoring time. That is the enforcement, and it is the only enforcement.

## Credentials

If raw enumeration surfaces a live credential, it is **not** a gate concern — under the collapse asymmetry it is never opened, quoted, or promoted. Mention its path in the menu as a one-line hygiene note ("rotate this"), and move on. Do not read it, do not paste it, do not "verify" it.
