# Separate what the lab uses from what it ships, on the leading dot

This repo both configures the agents that work on it and distributes config to
every host. Those are different things that would otherwise share a name, so the
cut is a single character: `.claude/` (leading dot) configures agents working *on*
Context Lab and ships nowhere; `claude/` (no dot) is the payload `install.sh` links
into `~/.claude/`.

## Considered options

Naming the payload something unambiguous — `payload/`, `user-tier/`, `dist/` — was
the obvious alternative and was rejected. The payload's contents are read by paths
that already say `.claude`, and a name that does not match the destination makes
every reference in `install.sh` and in the docs a translation step.

## Consequences

One character is a thin margin, and it is knowingly thin. Three mitigations, all
already in place: `README.md` states the cut, `claude/README.md` restates it at the
point of use, and `install.sh`'s link manifest spells out both sides of every link
as `<repo path>|<claude path>` so the mapping is never inferred.

Renaming later is cheap only until hosts are linked against it — after that a
rename breaks every live symlink on every machine at once.
