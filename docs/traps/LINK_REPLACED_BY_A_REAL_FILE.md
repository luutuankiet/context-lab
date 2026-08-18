---
symptom: "a host works fine but edits I make in the clone never reach it any more"
area: user-tier installer
verified: 2026-08-17
---

# A link replaced by a real file keeps working

## Symptom

You change `claude/statusline.sh` in the clone, commit, and the host does not
change. Nothing errors. The statusline still renders — it renders the *old* thing.
The host has silently stopped tracking the repo.

## Mechanism

This is the blind spot every symlink farm has. `~/.claude/statusline.sh` was a
symlink into the clone. Something replaced it with a regular file:

- a tool that writes to the path instead of through it (some editors do this on
  save; so does `mv` from a temp file, which is the *correct* way to write a file
  atomically and therefore common),
- a hand-copied file during a manual fix,
- an older installer that copied rather than linked.

The path still exists. Its contents are still valid. Every consumer keeps working.
The only thing that broke is the property nobody checks: that this file is a
*view* of the clone rather than a copy of it.

Copies are exactly what this design exists to avoid. Drift in a symlinked file
shows up as `git status` output; drift in a copy shows up as nothing at all until
somebody notices the two machines behave differently.

## Fix

`install.sh` detects it and refuses to be quiet about it:

- Under `--check` it fails with
  `<file> is a regular file, not a link into the clone`.
- Under a real install it moves the file aside to
  `~/.claude/backups/<name>.pre-context-lab.<timestamp>` before relinking, so a
  hand-made change is preserved rather than destroyed.

So the repair is `./install.sh`, and then read the backup to see what you had.

## How to verify

```sh
for f in statusline.sh hooks/token-tracker.sh; do
  printf '%-26s %s\n' "$f" "$([ -L ~/.claude/"$f" ] && readlink -f ~/.claude/"$f" || echo 'NOT A LINK')"
done
```

`CLAUDE.md` is deliberately absent from that list: it is a real host-local file
composed by `@`-import, not a link, so `NOT A LINK` is the correct state for it
(ADR 0011). Every line above must resolve into the clone. `[ -e ]` is not enough — that is the test
that passes for both shapes and is why the problem hides.

## The general rule

**Test for the mechanism, not the outcome.** "The file is there and the content is
right" is true in both the working and the broken state. `[ -L ]` is the assertion
that distinguishes them, and any check that omits it is measuring the wrong thing.
