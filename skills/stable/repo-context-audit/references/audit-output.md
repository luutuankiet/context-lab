# Reading the scanner

`scripts/audit.sh` runs eight filesystem checks and prints a state, two flags and
a route. It writes nothing and it never asks a model anything, so its output is
the same on every run against the same tree.

```
audit.sh [--repo DIR] [--stale-days N] [--notes-dir NAME]...
```

## The eight checks

| # | check | fails when |
|---|---|---|
| 1 | the always-loaded import | no `CLAUDE.md` containing `@AGENTS.md` |
| 2 | the contract file and its seam | no `AGENTS.md`, or no `<!-- Standard block.` marker in it |
| 3 | the collections | `docs/architecture`, `docs/traps`, `docs/reference` or `docs/adr` is missing or empty |
| 4 | the generated index | the repo's own generator says `--check` is stale |
| 5 | the emitted skills | either `.claude/skills/` index skill is absent, or its generated block is empty |
| 6 | orphan pages | a top-level `docs/*.md` carries no `title:`/`summary:`, so no collection claims it |
| 7 | stale dates | a page's `verified:` is missing, unparseable, or older than the threshold |
| 8 | unpromoted notes | an untracked working-notes directory exists, reported by byte count |

Check 2 also reports when `AGENTS.md` is over 4 KB. That is a **note, not a
failure** — a contract can legitimately be a little over budget, and it is the
human who decides whether the excess was a page in disguise.

## State is an ordered gate, not a set

```
cold        check 1 or 2 fails
structured  1 and 2 pass, and 3, 4 or 5 does not
wired       1 through 5 pass
```

Read it top down and stop at the first line that holds. **`structured` is the
fall-through**, which is the only reason every repository has a defined state: a
tree with a hand-made documentation directory and no contract file is `cold`, and
one with a contract, four collections and no skills is `structured` — neither is
undefined, and neither is halfway between two named things.

### The one tie-break

A repository can be `structured` because its index is stale rather than because
its skills are missing. Authoring skills that already exist would be a rewrite of
somebody's prose. So: **if check 5 passes but 3 or 4 does not, the route is
`route-repair.md`, not `route-author-skills.md`.** The scanner already applies
this and prints the route it chose; the rule is here so that the choice is
readable rather than magic.

## The two flags never touch state

Check 8 sets the **notes** flag. Checks 6 and 7 set the **drift** flag.

They are orthogonal to state, and this matters more than it looks. A fully wired
repository accumulates unpromoted notes continuously — that is the steady state
of a working repository, not a regression. A linear progress bar would report it
as one, and the operator would learn to ignore the scanner.

The scanner prints the state route as `route:` and any flag routes as `then:`, in
the order to run them.

## The frontmatter block

When check 6 or 7 fails, the scanner prints the frontmatter keys **for the
collection that actually drifted**, and nothing else. That is deliberate: repair
is the most frequent route, and it must never have to load
[page-formats.md](page-formats.md) to put back a key. A script is the cheapest
carrier of a schema — it costs nothing resident and it emits only the relevant
part.

## What it deliberately does not check

- **Anything requiring judgement.** Whether a page is good, whether a trap is
  really reference, whether an area is missing. Those are the routes' work.
- **Whether a fact is true.** `verified:` dates are compared to today, not to the
  code. Only a human re-reading the running code can do that.
- **Contents of a notes directory.** Check 8 counts bytes and files. It never
  opens one, because opening one is Gate 1 of `route-promote.md` and it happens
  after a human has seen the menu.
