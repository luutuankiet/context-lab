---
title: How this repo holds its own context
covers: where agent-facing context lives in this repo, what is always loaded, and how the generated index stays honest
verified: 2026-08-18
---

# How this repo holds its own context

This repo publishes a layout for keeping a project's accumulated knowledge in the
repository instead of in an agent's private notes. It uses that layout on itself.
If the two ever disagree, this page is the bug.

## Four places, and no fact is written twice

| where | what | when it is read |
|---|---|---|
| `AGENTS.md` | the contract: what the project is, its hard constraints, the layout, the check commands, and what tidy looks like | **always** — it is in context on every turn |
| `docs/` | prose: architecture, traps, reference | on demand, one page at a time |
| `docs/adr/` | decisions: why the repo is the way it is | on demand, when someone asks "why" |
| the issue tracker | anything with a next action | never loaded; it is not context |

`CLAUDE.md` at the repo root is an eleven-byte bridge containing exactly
`@AGENTS.md`. `AGENTS.md` is the cross-tool convention; Claude Code does not read
it natively, so the bridge is how one file serves both.

**An `@import` does not defer cost.** Imports load into the context window at
launch, exactly like inline text. `@AGENTS.md` is fine because it points at one
small file. Never `@`-import the docs tree hoping it will load lazily — deeper
pointers are plain markdown links, and that is why `AGENTS.md` links `docs/` rather
than importing it.

## The always-loaded file has a budget

`AGENTS.md` is roughly two kilobytes. That is not a style preference: it is paid on
every request, in every session, whether or not the session is about any of it.
Roughly four bytes per token is close enough for the arithmetic.

When it grows, the fix is not a smaller font. It is that something in it was not a
contract — it was a page, and it belongs in `docs/`.

## The docs index is generated

```sh
scripts/gen-docs-index.sh            # write every index
scripts/gen-docs-index.sh --check    # exit 1 if any of them is stale
```

One source of truth — the frontmatter on each page — rendered into the block
between the two marker comments in **three** files: `docs/README.md` and the two
skill bodies under `.claude/skills/`. It is dependency-free POSIX shell plus
`awk`, because this repo has no Node toolchain and reaching for a static site
generator to render one list would be absurd.

`scripts/gen-docs-index.sh` is a three-line wrapper. The generator itself is
`skills/stable/repo-context-audit/scripts/gen-docs-index.sh`, because a generator
carries a schema — the marker string, the frontmatter keys, the collections — and
a schema has one home. The lab runs the payload it ships.

**Never hand-maintain an index.** A hand-written one silently orphans pages: the
page still exists, nothing links to it, and nobody notices for a year. That is the
normal outcome, not the unlucky one.

Frontmatter is flat `key: value`, one per line, between `---` fences:

| collection | keys |
|---|---|
| `docs/architecture/` | `title`, `covers`, `verified` |
| `docs/traps/` | `symptom`, `area`, `verified` |
| `docs/reference/` | `title`, `summary`, `verified` |
| `docs/*.md` — a long-form guide | `title`, `summary`, `verified` |
| `docs/adr/` | none; the first `# ` heading is the entry |

`covers` and `symptom` are **search keys**, not topic names. They are written the
way a frustrated person would phrase the thing they are looking for, because that
is what they are matched against.

## Filenames are identifiers

Trap filenames are `SCREAMING_SNAKE_CASE` and name the **symptom, not the fix**.
They get quoted in code comments, commit messages and issue threads, so they are
never renamed. If the understanding changes, edit the body.

Architecture and reference filenames are `kebab-case`.

ADRs are `NNNN-kebab-slug.md`, sequentially numbered, created lazily. A merged ADR
is immutable: supersede it with a new one that names what it replaces, rather than
editing it. The tracker holds the argument; the ADR holds the conclusion; the pull
request links them.

## What is deliberately not here

- **No CI gate on any of this.** A repo laid out this way must be drivable by
  anyone with repo access without them knowing the layout has a name, and a repo
  that fails somebody's build to teach them a methodology has announced the
  methodology. `--check` exists so a person or an agent can run it; nothing runs it
  for them.
- **No hook.** Hooks here are installed at *user* tier, fleet-wide, so a
  format gate written as a hook would fire on every repo — including every repo
  that never opted in.
- **No per-entry operational-cache skills.** The layout allows a repo to keep an
  expensive-to-rediscover recipe as one small skill per entry under its own
  `.claude/skills/`. This repo has none — measured across the fleet, that shape
  yields roughly two admissible skills across fifty working-note directories, so
  it is a gated exception rather than a tier. What is under `.claude/skills/`
  here is the standard pair: `codebase-map` and `repo-maintenance`, each a short
  router around a generated table. **They are a build artifact, not a fifth place
  knowledge is stored** — every fact in them is in `docs/` — which is why
  [ADR 0004](../adr/0004-project-context-lives-in-the-repo-in-four-places.md)
  still says four places and needs no amendment.
- **Per-repo skills are never linked into the user-level skills directory.** The
  linker flattens by directory name, which would leak one project's recipes into
  every session on every host.
