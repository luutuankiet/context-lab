---
title: Third-party skills
summary: why no skill written by someone else is vendored here, which upstream collections are pointed at, and how to hydrate them on a host
verified: 2026-08-18
---

# Third-party skills

> **This repo contains zero third-party bytes.** Skills written by other people
> are *pointed at*, never copied in. You hydrate them on your own host by
> installing the upstream package; nothing about them is vendored here.

That is the whole rule, and it is checkable: `scripts/third-party-gate.sh`.

## Why there is no `wayfinder/` in this repo

Because there is a good one upstream and it is installed, not forked.

The predecessor repo did both halves at once — subscribed to the upstream
collection *and* kept its own copies of six of its skills in the project tier.
Upstream's README names that exact mistake: *"you subscribe rather than fork…
Pick one — installing both leaves you with every skill twice."*

Measured against the installed package at `068b6e0c6239`, those six copies were:

| copy | difference from upstream |
|---|---|
| `grilling` | byte-identical |
| `handoff`, `prototype`, `domain-modelling`, `wayfinder` | identical but for a stripped trailing newline — one byte each |
| `grill-me` | the only real edit |
| `teach` | not the skill at all — upstream's `docs/productivity/teach.md` page, verbatim, with frontmatter prepended |

The observed failure was not copy-then-diverge. It was **copy-then-*not*-diverge**:
five of the seven were, to the byte, a slower way of getting what
`claude plugin install` already gives you.

## The pointer

One row per upstream collection. This table is documentation — nothing parses
it — but it is the only record of *which wording* the writing in this repo was
composed against.

| skill collection | upstream | installed as | recorded sha | licence |
|---|---|---|---|---|
| mattpocock/skills | https://github.com/mattpocock/skills | `mattpocock-skills@claude-plugins-official` | `068b6e0c6239` | MIT |

**The sha is a receipt, not a pin.** `claude plugin install` has no `--version`,
`--ref` or `--sha` flag and there is no user-side lockfile; auto-update is on by
default for official marketplaces and fires up to ten minutes into a session.
The effective pin is publisher-side, in the marketplace manifest. So treat the
column above as *what this repo's prose was written against*, and expect the
installed copy to be newer. Making it a real pin is a separate question — see
[sandbox-cc#72](https://github.com/luutuankiet/sandbox-cc/issues/72).

## Hydrating them

`install.sh` step 3 already does it:

```bash
./install.sh                # installs the plugin along with the user tier
./install.sh --no-plugin    # user tier only, no third-party skills
```

Or by hand, without this repo:

```bash
claude plugin marketplace update claude-plugins-official   # stale caches report
                                                           # "not found in marketplace"
claude plugin install mattpocock-skills@claude-plugins-official
```

The plugin id lives in exactly one machine-readable place — `install_plugin()`
in `install.sh` — and the gate asserts that it also appears in this file, so the
script and this table cannot silently disagree.

### What subscribing costs, and what it cannot do

- **~1,609 tokens per session, always on**, for 25 skills — of which 14 are
  invisible to the model (user-invocable only). An opt-in that raises the *fixed*
  boot cost rather than the per-ticket cost.
- **A subscription cannot be curated.** `skillOverrides` short-circuits to `"on"`
  for plugin skills, and `disabledSkills` / `disableAllSkills` do not exist. It
  is all of them or none of them.
- **Collisions are narrower than they look.** Skills never shadow across levels —
  both appear — and plugin skills are always namespaced (`mattpocock-skills:x`).
  The entire collision surface is that a same-named local skill revokes the
  plugin skill's bare `/x` shortcut. It does not hide it.
- **Do not edit the plugin's cached copy.** The cache is a real writable git
  clone, but each version gets its own directory; the old one is marked
  `.orphaned_at` and swept after roughly 14 days. The one documented escape
  hatch is to symlink a checkout in as a version entry — never orphaned, never
  swept.

## The invariant, and what it actually checks

```bash
./scripts/third-party-gate.sh          # exit 0 = zero third-party bytes
```

It compares every Markdown file in the repo — tracked, plus untracked ones git
does not ignore, so a copy is caught before it is even `git add`ed — against
**every upstream version cached on this host**
(`~/.claude/plugins/cache/*/mattpocock-skills/*/`). That corpus is the same
bytes `install.sh` puts there, so the check needs no network and vendors
nothing. Two tests:

1. **Whole-file copy** — frontmatter stripped, trailing whitespace and blank
   lines normalised, then hashed. This is what catches a copy that was
   republished under a different name with new frontmatter.
2. **Partial copy** — the share of a file's substantial lines (>60 characters)
   that also appear somewhere upstream.

Honest limits, stated so nobody reads a green result as more than it is:

- It can only compare against versions **present in the local plugin cache**. On
  a host that has never installed the plugin it skips, loudly, rather than
  passing quietly.
- It knows about one upstream. A copy taken from some third collection is not
  something this check can see.
- Short files are exempt from test 2 by construction — there is no way to tell a
  shared five-line idiom from a copied one, and failing on that would train
  everyone to pass `--force`.
