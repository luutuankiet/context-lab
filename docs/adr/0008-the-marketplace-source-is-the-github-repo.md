# The marketplace source is the GitHub repo

Supersedes the source half of
[ADR 0006](0006-skills-ship-as-a-plugin-config-stays-linked.md). Skills still ship
as the `context-lab` plugin out of `.claude-plugin/marketplace.json`, and
`plugin.json` still declares no `version` — 0006 is right about both. What changes
is the marketplace **source**: `$REPO`, the host's own clone, becomes
`luutuankiet/context-lab`.

0006 chose the filesystem source for drift visibility, and stated the trade
plainly: "point the marketplace at the GitHub repo instead of the clone and skills
*are* served from the cache copy". That is now the wanted behaviour, not the cost.

## Why the trade flipped

- **The live-edit loop was never the loop being used.** Skills are edited in one
  clone on one host and consumed on six. The property 0006 optimised for — an
  uncommitted edit visible to the next session — applies only to the authoring
  host, and every other host still needed `git pull` to see anything.
- **The clone's *branch* silently became the payload.** Measured on thinkpad
  2026-08-18: with a directory source the recorded plugin version came out as
  `31d4acf`, the HEAD of a merged feature branch that happened to be checked out,
  not `main`. Nothing announces this. A remote source serves the default branch
  and cannot be repointed by a `git checkout`.
- **Auto-update was unavailable.** A directory source has nothing to fetch, so
  `autoUpdate` is meaningless on one. A remote source takes
  `extraKnownMarketplaces.context-lab.autoUpdate: true`, which the manifest now
  declares, and the host tracks `main` with no verb at all.
- **A consumer no longer needs a clone.** The plugin and the clone become
  independent: the clone is for working *on* this repo, the plugin is for using it.

## What this costs

- **Drift in `skills/` is no longer visible in `git status` on a live host**, since
  the host reads a fetched copy. That was 0003's decisive property and it is
  genuinely given up here — for skills only. The three config files in `claude/`
  are still symlinked out of the clone, so 0003 stands for those.
- **An edit needs commit, push, and `claude plugin update`** before any session
  sees it. On the authoring host that is three steps where there were none.
- **The cache copy is now authoritative**, inverting the warning in
  `docs/traps/CLAUDE_PLUGIN_ROOT_IS_EMPTY_IN_BASH.md`, whose body is updated to say
  so. Editing the cache still changes nothing durable — the next update overwrites
  it — but reading it now tells you the truth about what the host runs.

## Consequences

- The fleet update verb for skills is `claude plugin update context-lab@context-lab`,
  or nothing at all where `autoUpdate` is honoured. `git pull` updates the
  installer and the config files, not the skills.
- `plugin.json` stays versionless, and the reason strengthens: the recorded version
  is the source commit sha, so every push registers. A static `version` key on a
  remote source is the exact shape that lets `plugin update` no-op while reporting
  success — the failure `context-lab-private` is exposed to at `0.1.0`.
- **Migration is manual on any host that already has the directory-source
  marketplace.** `claude plugin marketplace add` will not repoint an existing
  entry, and `install.sh` skips a marketplace the CLI already knows. Run
  `claude plugin marketplace remove context-lab` before `./install.sh` on such a
  host. As of this ADR no host is known to be in that state, because the guard bug
  in `docs/traps/INSTALLER_REPORTS_A_PLUGIN_IT_NEVER_INSTALLED.md` meant the
  directory marketplace was never actually added anywhere.
- `skills/stable/` as the bucket mechanism, namespaced invocation, and base-directory
  script addressing are all unchanged from 0006.
