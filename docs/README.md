# Documentation

Every page here is written for a maintainer six months from now who opened
exactly this file from a search result and has nothing else loaded.

This index is generated. Run `scripts/gen-docs-index.sh` after adding or
renaming a page; `--check` fails if it is stale.

<!-- BEGIN GENERATED INDEX -- edit the pages, not this block -->

## Where things live

One page per area of the system. Read before going looking for where
something is implemented.

| page | covers | verified |
|---|---|---|
| [How this repo holds its own context](architecture/repo-context-layout.md) | where agent-facing context lives in this repo, what is always loaded, and how the generated index stays honest | 2026-08-17 |
| [The skills collection](architecture/skills-collection.md) | where the distributed skills live, how the stable bucket ships as a plugin, and why no third-party skill is vendored here | 2026-08-18 |
| [The user-tier installer](architecture/user-tier-installer.md) | how a host gets its Claude Code config, what install.sh actually writes, and what --check can and cannot prove | 2026-08-17 |

## Traps

Failure modes that produce no error message, indexed by the symptom you
would observe. Read before debugging behaviour that is wrong but not
crashing.

| symptom | page | area | verified |
|---|---|---|---|
| install.sh --check reports everything healthy but the host is not running what main says it should | [CHECK_PASSES_ON_A_STALE_CLONE](traps/CHECK_PASSES_ON_A_STALE_CLONE.md) | user-tier installer | 2026-08-17 |
| a skill edit is saved in the clone, git status shows it, and every session still runs the old text | [EDITS_ONLY_REACH_A_SESSION_AFTER_A_COMMIT](traps/EDITS_ONLY_REACH_A_SESSION_AFTER_A_COMMIT.md) | skills collection | 2026-08-18 |
| a shell script in this repo aborts with unbound variable on one machine only, and runs fine everywhere else | [EMPTY_ARRAY_IS_FATAL_UNDER_SET_U](traps/EMPTY_ARRAY_IS_FATAL_UNDER_SET_U.md) | shell scripts | 2026-08-17 |
| a host works fine but edits I make in the clone never reach it any more | [LINK_REPLACED_BY_A_REAL_FILE](traps/LINK_REPLACED_BY_A_REAL_FILE.md) | user-tier installer | 2026-08-17 |
| a hook that another tool installed stopped firing after I ran install.sh, and settings.json looks fine | [PRETOOLUSE_HOOK_GONE_AFTER_INSTALL](traps/PRETOOLUSE_HOOK_GONE_AFTER_INSTALL.md) | user-tier installer | 2026-08-17 |
| git status in the context-lab clone shows claude/CLAUDE.md modified on a host I only just installed, and I did not edit it | [RTK_IMPORT_APPENDED_TWICE](traps/RTK_IMPORT_APPENDED_TWICE.md) | user-tier installer | 2026-08-17 |

## Reference

Simply true, and expensive to re-derive.

| page | summary | verified |
|---|---|---|
| [The owned settings keys](reference/owned-settings-keys.md) | which sixteen keys install.sh takes over, which are deliberately left to the host, and which are actively deleted | 2026-08-17 |

## Decisions

Why the repo is the way it is. A merged decision is immutable -- supersede
it with a new one rather than editing it.

- [Separate what the lab uses from what it ships, on the leading dot](adr/0001-two-trees-cut-on-the-leading-dot.md)
- [Buckets cut on maturity; repos cut on privacy](adr/0002-buckets-cut-on-maturity-repos-cut-on-privacy.md)
- [Distribute by symlink and `git pull`, never by copy or package](adr/0003-distribute-by-symlink-and-git-pull.md)
- [Project context lives in the repo, in four places](adr/0004-project-context-lives-in-the-repo-in-four-places.md)
- [Nothing mechanical enforces the layout](adr/0005-nothing-mechanical-enforces-the-layout.md)
- [Skills ship as a plugin; config stays linked](adr/0006-skills-ship-as-a-plugin-config-stays-linked.md)

<!-- END GENERATED INDEX -->
