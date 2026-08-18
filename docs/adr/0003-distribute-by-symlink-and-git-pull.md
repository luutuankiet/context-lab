# Distribute by symlink and `git pull`, never by copy or package

Every host clones this repo once and links individual files out of it. Updates are
`git pull`. Nothing is copied onto a host, nothing is pushed to one, and no
credential is installed anywhere — a public repo needs none.

The decisive property is **drift visibility**. An edit made on a host writes
straight through the link into the tracked file, so it shows up as `git status`
output in the clone. The same edit made to a copy shows up as nothing at all.

## Considered options

- **Copy on install.** Rejected on evidence: a statusline fix hand-applied on one
  host went unnoticed on another for weeks, and a copy-based re-install would have
  silently reverted it.
- **A published package.** Rejected: it versions the collection, and versioning
  buys nothing for a single operator while adding a release step between writing a
  skill and using it.
- **Push over SSH from a central host.** Rejected, and dead rather than deferred:
  git is already on every host, and a public repo needs no credential, so the push
  design would put new secrets on daily drivers to solve a problem `git pull`
  already solves.
- **A dotfile manager (`chezmoi`, `stow`).** Rejected: the measured per-host
  variance was one binary substitution. That is not enough variance to justify a
  templating layer.

## Consequences

**Never a directory symlink.** `~/.claude/` holds `.credentials.json`,
`history.jsonl`, `projects/`, `sessions/` and twenty-odd other runtime entries that
Claude Code owns; linking the directory would commit all of it. `install.sh` links
three named files and nothing else.

**`settings.json` is patched by key, never replaced** — other tools write to it,
and backup files from at least one of them prove it.

Two costs are accepted knowingly. A host that is never `git pull`ed silently keeps
running old config while every check passes
(`docs/traps/CHECK_PASSES_ON_A_STALE_CLONE.md`), and because work on this repo
happens *in* the clone that hosts are linked to, checking out a branch repoints the
live user tier for as long as it stays out.
