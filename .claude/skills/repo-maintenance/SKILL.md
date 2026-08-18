---
name: repo-maintenance
description: This repo keeps a catalogue of its own traps — failure modes that produce no error, so you find them by symptom, not by stack trace — plus its reference pages and its decision records. Use before debugging behaviour that is wrong but not crashing, before editing shared state, and whenever you finish debugging something that cost more than an hour.
---

# Traps in this repo

Everything expensive here has failed **silently**. A host keeps running the
version it installed last month; a symlink quietly becomes a real file; a hook
another tool installed stops firing. There is no stack trace to search — there is
usually no error at all — so the catalogue below is keyed on **the symptom you
would observe**, not on the part of `install.sh` at fault.

**Before you debug anything that misbehaves without erroring, scan this table.**
Then open exactly one file. Each page is self-contained — you will not need to
open a second one.

<!-- BEGIN GENERATED INDEX -- edit the pages, not this block -->

## Traps

Failure modes that produce no error message, indexed by the symptom you
would observe. Read before debugging behaviour that is wrong but not
crashing.

| symptom | page | area | verified |
|---|---|---|---|
| install.sh --check reports everything healthy but the host is not running what main says it should | [CHECK_PASSES_ON_A_STALE_CLONE](../../../docs/traps/CHECK_PASSES_ON_A_STALE_CLONE.md) | user-tier installer | 2026-08-17 |
| a path built from $CLAUDE_PLUGIN_ROOT inside a skill resolves to /skills/... and the command fails as if the file were missing | [CLAUDE_PLUGIN_ROOT_IS_EMPTY_IN_BASH](../../../docs/traps/CLAUDE_PLUGIN_ROOT_IS_EMPTY_IN_BASH.md) | skills collection | 2026-08-18 |
| a shell script in this repo aborts with unbound variable on one machine only, and runs fine everywhere else | [EMPTY_ARRAY_IS_FATAL_UNDER_SET_U](../../../docs/traps/EMPTY_ARRAY_IS_FATAL_UNDER_SET_U.md) | shell scripts | 2026-08-17 |
| install.sh prints `ok <plugin> installed`, the session has none of that plugin's skills, and `claude plugin list` does not show it | [INSTALLER_REPORTS_A_PLUGIN_IT_NEVER_INSTALLED](../../../docs/traps/INSTALLER_REPORTS_A_PLUGIN_IT_NEVER_INSTALLED.md) | user-tier installer | 2026-08-18 |
| a host works fine but edits I make in the clone never reach it any more | [LINK_REPLACED_BY_A_REAL_FILE](../../../docs/traps/LINK_REPLACED_BY_A_REAL_FILE.md) | user-tier installer | 2026-08-17 |
| a hook that another tool installed stopped firing after I ran install.sh, and settings.json looks fine | [PRETOOLUSE_HOOK_GONE_AFTER_INSTALL](../../../docs/traps/PRETOOLUSE_HOOK_GONE_AFTER_INSTALL.md) | user-tier installer | 2026-08-17 |
| git status in the context-lab clone shows claude/CLAUDE.md modified on a host I only just installed, and I did not edit it | [RTK_IMPORT_APPENDED_TWICE](../../../docs/traps/RTK_IMPORT_APPENDED_TWICE.md) | user-tier installer | 2026-08-17 |

## Reference

Simply true, and expensive to re-derive.

| page | summary | verified |
|---|---|---|
| [The owned settings keys](../../../docs/reference/owned-settings-keys.md) | which nineteen keys install.sh takes over, which are deliberately left to the host, and which are actively deleted | 2026-08-18 |

## Decisions

Why the repo is the way it is. A merged decision is immutable -- supersede
it with a new one rather than editing it.

- [Separate what the lab uses from what it ships, on the leading dot](../../../docs/adr/0001-two-trees-cut-on-the-leading-dot.md)
- [Buckets cut on maturity; repos cut on privacy](../../../docs/adr/0002-buckets-cut-on-maturity-repos-cut-on-privacy.md)
- [Distribute by symlink and `git pull`, never by copy or package](../../../docs/adr/0003-distribute-by-symlink-and-git-pull.md)
- [Project context lives in the repo, in four places](../../../docs/adr/0004-project-context-lives-in-the-repo-in-four-places.md)
- [Nothing mechanical enforces the layout](../../../docs/adr/0005-nothing-mechanical-enforces-the-layout.md)
- [Skills ship as a plugin; config stays linked](../../../docs/adr/0006-skills-ship-as-a-plugin-config-stays-linked.md)
- [One entry point for repo context, reached by a scanner](../../../docs/adr/0007-one-entry-point-reached-by-a-scanner.md)
- [The marketplace source is the GitHub repo](../../../docs/adr/0008-the-marketplace-source-is-the-github-repo.md)
- [A tool's manual lives in the tool's repo, and the catalogue only points](../../../docs/adr/0009-a-tools-manual-lives-in-the-tools-repo.md)

<!-- END GENERATED INDEX -->

The same tables, browsable, are [docs/README.md](../../../docs/README.md).

## Adding a trap

Write one when you have just spent real time on something that would have taken
minutes if someone had told you. Three tests, all must pass:

1. **It has a symptom.** If a fact is merely true, it is reference, not a trap.
   *If it has a symptom it is a trap; if it is just true it is reference.*
2. **Nothing cheaper catches it.** A doc is the *last* resort, because it only
   works if someone reads it. Stop at the first rung that holds:

   | rung | use when | this repo |
   |---|---|---|
   | make it a **type error** | the mistake is expressible in the type system | **none.** This is bash and markdown; there is no type system to reach for, so this rung never holds here. |
   | make it a **test** | the mistake is an assertable behaviour | `./test-install.sh` (assertions against a throwaway `$HOME`), `./install.sh --check`, `scripts/skills-publish-gate.sh`, `scripts/gen-docs-index.sh --check`, and each skill's own `tests/run.sh`. No CI runs any of them. |
   | **comment at the site** | there is exactly one line where someone could get it wrong | **this is the norm here and the rung that usually holds.** `install.sh` carries 122 comment lines against 452 total. See the header of `scripts/skills-publish-gate.sh`, which spends fifteen lines saying why each of its three checks exists — including the one `claude plugin validate` warning that is deliberate. |
   | **a doc** | the mistake can be made from any of several files, or from a file that does not exist yet | the catalogue above |

   Before adding one, say out loud which single line you would have commented
   instead — if you can name it, comment it and stop.
3. **It is not already in the table.** Extend the existing file. Two docs on one
   fact is how a catalogue rots.

Then:

- **Filename is the identifier.** `SCREAMING_SNAKE.md`, describing the symptom,
  not the fix. It is quoted in code comments and commit messages, so it never
  gets renamed — if the understanding changes, edit the body.
- **`symptom:` is the search key.** The string a frustrated person would paste
  into a search box, not a topic name.
- **Date it.** `verified:` is the day someone last confirmed it in the running
  code. An undated trap is a claim with no expiry.
- **Regenerate the index**: `scripts/gen-docs-index.sh`. The block above is
  generated; hand edits to it are overwritten.

## Writing the body

The reader is a maintainer six months from now who opened this one file from a
search result and has **no other context loaded**. Not you, not this session.

- Resolve every reference inline. No "see the other doc", no ticket numbers, no
  "as discussed". If a line number matters, quote the code.
- Publishing tone. It is a page on the project's documentation site, not a note
  to self.
- Lead with the symptom, then the mechanism, then the fix, then how to verify.
  Someone in the middle of a bug reads the first two lines and stops.
- Include the **evidence** — the measured numbers, the observed values, the
  verbatim code. A trap without evidence gets argued with.
- **Say what is deliberate.** A lot of what looks wrong in this repo is a trade
  someone made on purpose: no CI, no hook, versionless plugin manifest, named
  file links rather than a directory symlink. Write down which, and what the
  trade was.

## The other collections

`docs/` holds five kinds of page, all generated into the same index by the same
script, all governed by the rules above:

| directory | what belongs there | frontmatter |
|---|---|---|
| `docs/traps/` | it has a symptom | `symptom`, `area`, `verified` |
| `docs/architecture/` | where behaviour lives — one page per area | `title`, `covers`, `verified` |
| `docs/reference/` | simply true, no symptom, worth not re-deriving | `title`, `summary`, `verified` |
| `docs/adr/` | **why the repo is the way it is** — a decision record | none; the `# ` heading is the entry |
| `docs/*.md` | a long-form guide belonging to no single area | `title`, `summary`, `verified` |

The architecture pages are the `codebase-map` skill's index; read that skill
before adding one. The escalation ladder does **not** apply to them — a map is not
a warning. Everything else does: date it, resolve references inline, regenerate
the index.

### Decision records

`docs/adr/NNNN-kebab-slug.md`, sequential, created lazily. Offer one only when
**all three** hold:

1. **hard to reverse** — if it is easy to reverse, skip it; you will just reverse it
2. **surprising without context** — otherwise the code explains itself
3. **the result of a real trade-off** — if there was no genuine alternative, there
   is nothing to record beyond "we did the obvious thing"

One to three sentences is a complete record: the context, what was decided, why.

**A merged record is immutable.** Superseding means a *new* file that names what
it replaces; the old one stays readable, because the reason a decision was made is
not invalidated by the decision changing. `0006` supersedes part of `0003` that
way, and `0003` is still there.

This is the one destination that is append-only and unrecoverable. A trap can be
rewritten later; a rationale never written is gone.

## Removing a trap

**Before trusting a page, check it is still true.** These describe code, and code
moves. If the underlying cause is fixed, **delete the file** and say so in the
commit message. Do not leave it with a "fixed in vX" note — a stale trap costs a
reader the same time as a real one, and costs the catalogue its credibility, which
is the only thing making anyone open the next page. If the fix came with a comment
at the site, that comment is now the record.
