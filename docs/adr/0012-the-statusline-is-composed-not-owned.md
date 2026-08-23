# The statusline is composed by a host-owned dispatcher, not owned by this repo

Claude Code renders exactly one statusline, from exactly one settings value.
Until now this repo owned that value outright: `claude/statusline.sh` rendered
the whole line, and anything else that wanted to appear on it had to negotiate a
patch into this repo and wait for this repo's release.

That was fine while there was one contributor. It stops being fine the moment
there are two, and it cannot be fixed by making a plugin ship its own
declaration: a plugin's `settings.json` is parsed against a two-key allowlist
and `statusLine` is **stripped before the file is used** — no error, no warning,
nothing in the `/plugin` errors view. There is no contest to win and no merge to
sit at the bottom of. Two upstream requests to make plugin settings carry a
lowest-precedence `statusLine` are closed `not_planned`.

**Decision: a dispatcher owns the `statusLine` value and composes the line from
executables it discovers in `statusline.d/` directories. This repo contributes
`statusline.d/10-context` and owns nothing else about the line.**

## What a contributor is

An executable file in `statusline.d/`, named `NN-<name>`. It receives the
session JSON on stdin, prints its own fragment, and knows nothing about any
other contributor. Adding or removing one is committing or deleting a file —
there is no install step, no manifest edit and no registration, which is the
same shape as publishing a skill by moving a directory into `skills/stable/`.

Ordering is the basename, so position is a property of the name rather than of
which repo the file arrived from: `00`–`19` for the primary line, `20`–`79` for
ordinary contributors, `80`–`99` for warnings and alerts, which belong last.

## Why a directory rather than a list

Every alternative puts two writers on one file. **Wrapper chaining** — each
installer replacing the current command with one that calls the previous — is
destroyed by ordinary events: uninstalling a middle link strands the rest,
reinstalling doubles a link, and a removed repo leaves a command pointing at a
deleted file, which blanks the line. **A shared manifest** of segment paths is
the same problem in smaller print: one JSON file, two read-modify-write
installers, no locking, and a clobbered entry that looks exactly like a plugin
that never installed.

A directory has no merge. One contributor is one file, adding and removing are
independent operations by independent parties, `ls` shows the whole state, and a
contributor that disappears leaves nothing behind. This is what `*.d` has meant
in Unix since `run-parts`.

## Why the dispatcher lives on the host

It is the one genuinely shared piece. Putting it in this repo's clone would make
every other contributing repo depend on this one to render at all, which is the
coupling the mechanism exists to remove. So it is written to a host path,
byte-identical in every repo that ships it, by whichever installer runs, guarded
by a `dispatcher-version:` marker so repeat installs converge and upgrades are
monotone.

Rejected: **a third published artifact** both repos depend on — cleaner
ownership, one more thing to release, and not worth a release cycle for under
two hundred lines that change roughly never.

## What this constrains, permanently

- **The `statusLine` value lives in the host's own `settings.json`** and names a
  real path. `${CLAUDE_PLUGIN_ROOT}` cannot appear in it — a command in
  `settings.json` referencing that variable throws.
- **The scan is gated on `enabledPlugins`.** Scanning every marketplace clone
  unconditionally would mean that merely *adding* a marketplace silently runs
  its code on every render, which is the class of surprise this exists to
  prevent. `enabledPlugins` is where the human already consented.
- **A contributor never blanks the line.** It renders without the contributor.
  An error is named on screen as `! statusline:<name>`; a **timeout is not**,
  because it is transient and the next render recovers it, and an indicator that
  cries wolf on an ordinary cold start is one you learn to ignore.
- **The dispatcher never edits a contributor's bytes.** Truncation belongs to
  the contributor, against `COLUMNS`, because cutting a string mid-ANSI-escape
  corrupts the colour state of the rest of the line.
- **The budget is enforced without `timeout(1)` and without GNU coreutils**, by
  one watchdog process rather than a poll loop. The oldest host in the fleet has
  neither, and a poll loop forks per tick — a 400 ms budget measured 2.2 s of
  wall clock there, a fivefold divergence between the counter and reality.

`claude/statusline.sh` survives as a shim onto `statusline.d/10-context`, so a
host still pointed at the old path keeps rendering what it always did. Retiring
it, its symlink and the settings entries that name it is separate work.
