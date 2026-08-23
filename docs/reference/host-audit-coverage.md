---
title: What the host audit checks, and what it cannot see
summary: the eleven things context-lab-audit compares against remote HEAD, the two classes it sorts drift into, the three states it deliberately reports as facts rather than failures, and the four blind spots that are structural rather than unfinished
verified: 2026-08-23
---

# What the host audit checks, and what it cannot see

The `context-lab-audit` skill answers one question about the machine it runs on:
**does what is on this disk match what this repository intends?** It reports; it
does not repair. `install.sh` is the thing that writes, and a human runs it.

Intent is **remote HEAD** — fetched at the start of every run, and read with
`git show` out of the fetched commit. Never the working tree, never a receipt
written at install time. A receipt answers *what did I do last time*, which is a
different question and a comforting one.

**A failed fetch ends the run.** The scanner names the remote it could not reach
and exits `2` having audited nothing. There is no fallback to the local copy,
because a clean bill of health derived from a source just declared
unauthoritative is worse than no answer at all.

## What is compared

Every intended value is read out of remote HEAD. The manifests are read out of
`install.sh` itself rather than restated here, so the audit and the installer
cannot quietly disagree.

| # | what | intent read from | drift looks like |
|---|---|---|---|
| 1 | remote HEAD | `git fetch origin HEAD` | unreachable → exit `2` |
| 2 | the marketplace clone | the fetched sha | not an ancestor; modified tracked files |
| 3 | the installed plugin | the clone's `HEAD` | absent, disabled, or built from an older commit than the clone holds |
| 4 | the owned settings keys | `claude/settings.owned.json` | a key whose value the merge would change |
| 5 | the unset settings keys | `SETTINGS_UNSET` in `install.sh` | the key is still present |
| 6 | duplicated hook entries | the plugin's own `hooks/hooks.json` | a settings entry with the same command signature |
| 7 | the statusline dispatcher | `claude/statusline-dispatch.sh` | absent, older marker, or same marker and different bytes |
| 8 | the statusline contributors | mode `100755` under `statusline.d/` | absent, or present without the executable bit |
| 9 | the user-memory import | `MEMORY_IMPORT_TAIL` in `install.sh` | absent, duplicated, still a symlink, or resolving to nothing |
| 10 | the linked files | `LINKS` in `install.sh` | absent, dangling, or a regular file where a link belongs |
| 11 | the shell exports | the export list in `install.sh` | missing from the login shell's rc |

A check that **cannot run** — an unreadable manifest, a `settings.json` that is
not valid JSON — is reported as `unknown` and counted against the verdict. It is
never allowed to read as a pass.

## The two classes

`[install]` — **repairable by re-running the installer.** Rows 2 through 5 and 7
through 11. Named, and then a human runs `./install.sh`.

`[approve]` — **repairable by nothing anyone can run.** Row 6, and today it is
the only member. The settings merge adds and changes but never deletes, so a
retired entry survives every re-run; once the plugin declares the same command
in its own manifest, both fire and the command runs twice per event, silently.
The audit prints the exact edit, says what agreeing to it costs, and applies it
only on approval.

## Three differences that are reported as facts, not failures

- **Behind remote HEAD, as an ancestor.** The platform runs its own plugin
  update once per session start, which walks an ancestor forward without anyone
  owning a scheduler. The distance is printed; reporting it as a failure would
  be reporting the mechanism working.
- **A dispatcher newer than this repository's.** The dispatcher is host
  infrastructure written by whichever installer runs first, and the replace rule
  is monotone by design. A newer copy means something else got there first.
- **A linked file whose clone is not at remote HEAD.** A working copy on a
  branch is the normal case for anyone editing this repository.

## What it cannot see

Structural, not unfinished. Say them out loud whenever the verdict is "healthy",
because a silent blind spot reads as coverage.

- **This host.** An audit never enumerates machines; a fleet view would require
  the repository to carry a list of them.
- **Only what this repository ships.** Anything installed from another source is
  invisible here — including its complete absence. A host missing it looks
  perfectly healthy from this side.
- **Nothing about behaviour.** That a hook is declared exactly once is checked;
  that it does the right thing when it fires is not.
- **Nothing about the future.** Intent is the remote at the moment of the fetch,
  so an unpushed commit reads as drift — correctly.

## The side effect it does have

The audit refreshes the cached remote head that a statusline contributor reads
to render "this host is behind its remote". No render touches the network, and
nothing else on a host refreshes that cache — so the fetch this audit has
already paid for is where it gets updated. The entry for this repository's
marketplace is merged into whatever the file already holds; entries belonging to
other marketplaces are never touched. `--no-refresh` skips it, and is the only
way to run the audit as a pure read.

The consequence is worth stating rather than fixing: that indicator lights up
only in renders following an audit.
