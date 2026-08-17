# Context Lab

The lab where agent context is designed, and the package that ships it to every
host in the fleet.

Two things live here and they must never be confused:

| tree | role | who reads it |
|---|---|---|
| `skills/` | the **distributed** skills collection | every host, via `install.sh` |
| `claude/` | the **distributed** user tier — the payload installed into `~/.claude/` | every host, via `install.sh` |
| `install.sh` | the distributor | you, once per host |
| `docs/` | the lab's own writing | humans |
| `.claude/`, `AGENTS.md`, `CLAUDE.md` | **this repo's own** harness config | agents working *on* Context Lab |

## The one structural requirement

> Two trees must stay unambiguous: what Context Lab uses to **maintain itself**,
> versus what it **distributes**. Otherwise the lab's own scaffolding leaks into
> every repo it touches.

The cut is the leading dot:

- **`.claude/`** (dot) — configures agents *working on this repo*. Never shipped.
- **`claude/`** (no dot) — the payload *shipped to* `~/.claude/` on every host.

⚠️ These two names differ by one character. Before you edit either, read the
path twice. `claude/README.md` restates this at the point of use.

## The naming rule

*Context Lab* names the lab. **What it emits into any other repo carries no
brand at all** — a canonical shape any agent reads as "this repo is laid out
well," not a methodology to learn first.

The name is spoken in exactly one place: the brownfield converter you invoke by
name. If you find the string "Context Lab" inside a file destined for another
repo, that file is wrong.

## Skill buckets

The repo boundary cuts on **privacy**, not maturity. This repo is public, so
maturity is the only axis here:

| bucket | meaning |
|---|---|
| `skills/in-progress/` | live iteration; may change or disappear without warning |
| `skills/stable/` | graduated; safe to depend on |
| `skills/deprecated/` | the off-switch — excluded from install by path |

Graduation is a **gate that can fail**: valid frontmatter + privacy scrub +
owner's call. The catalog is *generated* from frontmatter — there is no
hand-written docs page, because every hand-maintained second copy in the
predecessor repo drifted.

Skills that encode fleet topology do not live here. They live in the private
companion repo.

## Status

Phase 1 scaffolding. The trees exist; the contents arrive in later phases:

| tree | filled by |
|---|---|
| `skills/*` | the skills migration, gated on the privacy scrub |
| `claude/*` | the settings manifest + `install.sh` work |
| `install.sh` | same |

Until then the stubs refuse to run rather than half-work.
