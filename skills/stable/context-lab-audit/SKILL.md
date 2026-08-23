---
name: context-lab-audit
description: Audit this host against what the context-lab repository intends — the installed plugin, the owned settings keys, the statusline dispatcher and its contributors, the user-memory import and the shell exports — reporting what has drifted, which drift a re-run of install.sh repairs, and which drift no re-run can. Use when a host behaves as if it is running older config, when a hook seems to fire twice, after a manual edit to settings.json, or when asked whether a machine is up to date.
metadata:
  verified: "2026-08-23"
---

# Host audit

One question, for the machine you are on: **does what is on this disk match
what the repository intends?**

## Run the scanner first

```bash
<this skill's base directory>/scripts/audit.sh
```

Everything mechanical happens there. It fetches, reads the host, classifies,
and refreshes the cached remote head. Read its output; do not re-derive any of
it by hand.

| exit | meaning |
|---|---|
| `0` | audited, nothing drifted |
| `1` | audited, drift found |
| `2` | **intent could not be established — nothing was audited** |

## Intent is remote HEAD, and a failed fetch ends the run

The scanner reads every intended value out of the fetched commit, never off the
working tree and never out of a receipt written at install time — a receipt
answers *what did I do last time*, which is not the question.

**On exit `2`, report which remote could not be reached and why, and stop.**
Never substitute the copy on this disk. That would hand back a clean bill of
health derived from a source the scanner has just finished calling
unauthoritative, which is worse than no answer.

## Behind is not drift

A clone that is an **ancestor** of remote HEAD is a healthy host: the platform
runs its own plugin update once per session start, which walks it forward with
nobody owning a scheduler. The scanner prints the distance as a `fact`. Repeat
it as a fact. Only a **non-ancestor**, a **modified tracked file** or something
**absent** is drift.

## Two classes, and only one of them is yours to act on

**`[install]` — repairable by re-running the installer.** Name them, say
`./install.sh` is the repair, and stop. **You do not run it.** It mutates a
login shell rc, a settings file and a host path; a human decides when.

**`[approve]` — repairable by nothing you can run.** The settings merge adds and
changes but never deletes, so an entry that should go survives every re-run —
and one left pointing at a command the plugin now also declares makes that
command run twice per event, silently. The scanner prints the exact edit and
the command that applies it. Show both, say plainly what agreeing costs, and
**apply it only after the human has said yes, in that turn**. Details and the
wording to use: [references/stale-hook-entries.md](references/stale-hook-entries.md).

**`unknown` — the check could not run.** Treat as drift and say which manifest
was unreadable. A check that passes because it could not run is the failure
this skill exists to refuse.

## What it cannot see

Say this out loud whenever the answer is "the host looks healthy", because a
silent blind spot reads as coverage:

- **This host only.** An audit never enumerates machines. There is no fleet view
  here and there will not be one.
- **Only what this repository ships.** Anything installed from another source is
  invisible to this scanner, including its complete absence — a host missing it
  looks perfectly healthy from here.
- **Unpushed work reads as drift**, correctly: intent is the remote, not your
  branch.

## Report in this shape

- **verdict** — one line: the commit audited against, and the two counts
- **facts** — behind-ness, render order, anything different but not wrong
- **`[install]`** — one line each, then the single sentence "run `./install.sh`"
- **`[approve]`** — the edit, what it costs, and an explicit ask
- **not checked** — the blind spots above, every time
