---
symptom: "a skill edit is saved in the clone, git status shows it, and every session still runs the old text"
area: skills collection
verified: 2026-08-18
---

# Edits only reach a session after a commit

You edit `skills/stable/<skill>/SKILL.md`, save, start a fresh session, invoke the
skill — and get the previous wording. Nothing errors. `git status` shows your
change. `claude plugin update context-lab@context-lab` says *"already at the
latest version"* and exits 0.

## Why

Skills ship as a plugin (ADR 0006), and a plugin is **copied** into
`~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`. Sessions read the
copy, never the clone.

`plugin.json` declares no `version`, so the version *is the source commit sha*.
An uncommitted edit does not move the sha, so there is nothing for `plugin update`
to update — and it reports that state as success, because from its point of view
the cache does match the source's committed state.

This is the accepted cost of versionless auto-propagation, and it is strictly
better than the alternative it was chosen over: with a hand-written `version`,
*committed and pushed* work is stranded too, on every host, until somebody
remembers to bump a number.

## The fix

Commit, then install:

```sh
git commit -am "..." && ./install.sh
```

Then **restart the session** — `plugin update` prints *"Restart to apply changes"*
because a running session has already loaded its skill set.

## Checking what a host is actually running

```sh
ls ~/.claude/plugins/cache/context-lab/context-lab/   # the sha(s) present
git -C ~/dev/context-lab rev-parse --short=12 HEAD    # what the clone is on
claude plugin details context-lab                     # the skills the session sees
```

If the first two disagree, the host is running old skills. Old version
directories are left behind on update, marked `.orphaned_at` and swept after
about two weeks — so seeing several is normal, and only the one matching HEAD is
live.

## Not this

Do **not** edit files under `~/.claude/plugins/cache/`. They are derived, they are
replaced on the next update without warning, and an edit there is invisible to
`git status` — the exact drift ADR 0003 exists to prevent.
