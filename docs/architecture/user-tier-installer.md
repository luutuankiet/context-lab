---
title: The user-tier installer
covers: how a host gets its Claude Code config, what install.sh actually writes, and what --check can and cannot prove
verified: 2026-08-23
---

# The user-tier installer

`install.sh` puts the contents of `claude/` onto a host and proves they are still
there. It is the only executable in this repo that touches a machine.

```sh
./install.sh              # install — idempotent, safe to re-run
./install.sh --check      # verify only, mutate nothing, non-zero exit on drift
./install.sh --dry-run    # print every mutation without performing it
./test-install.sh         # assertions against a throwaway $HOME
```

Escape hatches, all valid alongside `--check`: `--no-rtk`, `--no-plugin`,
`--no-shell`.

## It registers things; it places no executables

Nothing in this repo is symlinked or copied onto a host. There is no `LINKS`
array and no `link_files()` — both were removed in
[ADR 0014](../adr/0014-executables-ship-as-plugin-content.md). What the
installer writes is a registration, a memory import line, a settings merge and a
shell block, and that is the whole list.

Executables reach a host as **plugin content** and are addressed by
`${CLAUDE_PLUGIN_ROOT}`, which resolves to a cache directory keyed by the commit
the marketplace published:

| what | how it reaches a host |
|---|---|
| the token tracker | `hooks/hooks.json` in this plugin, bound to `UserPromptSubmit` and `PostToolUse` |
| the statusline | `statusline.d/10-context`, discovered by the dispatcher at render time |
| skills | `skills/stable/`, declared in `plugin.json` |

`claude/CLAUDE.md` is separate again: user memory is composed by `@`-import.
`~/.claude/CLAUDE.md` is a real host-local file that no repository owns, and
step 4b adds exactly one line to it pointing at the marketplace clone
(`~/.claude/plugins/marketplaces/context-lab/claude/CLAUDE.md`). A second tier
adds its own line without contending for the file. See
[ADR 0011](../adr/0011-user-memory-composes-by-import-not-symlink.md).

**The freshness verb is `claude plugin update`.** A `git pull` in a working
checkout changes nothing about what a host executes, which is the point: what
runs is a published version, not whatever a working copy happens to hold.

**Plugin hooks merge with settings hooks; they do not override them.** A host
that gains the plugin hook while keeping the old `settings.json` entry fires the
tracker twice per event, silently. That is why `hooks.UserPromptSubmit` and
`hooks.PostToolUse` are in `SETTINGS_UNSET` — see step 5.

## The steps, in order

**1. Prerequisites.** Hard requirements are `jq awk sed git curl`. Wanted but never
fatal: `flock sha256sum node gh rg`. `bc` is *deliberately* absent from both lists —
one host in the fleet has never had it, and both consumers (the statusline
contributor, `token-tracker.sh`) were moved to `awk` precisely so this never has to
reach for a package manager. Re-introducing a `bc` dependency anywhere breaks that
host silently: the statusline fails per render and nothing prints an error.

**2. rtk — two commands, not one.** rtk's own `install.sh` writes only the binary
and touches nothing under `~/.claude`. `rtk init -g --auto-patch` is what owns the
harness surfaces. `--auto-patch` is not optional: the default patch mode blocks on
stdin and would hang a non-interactive install forever.

Do **not** track `~/.claude/hooks/rtk-rewrite.sh` or `.rtk-hook.sha256` here. rtk's
own migration path deletes both by design.

**3. Marketplace plugins** — two of them, from one list of
`plugin|marketplace|source` specs: `mattpocock-skills@claude-plugins-official`
(third-party hydration) and `context-lab@context-lab`, whose marketplace source is
`$REPO` — this clone. The `enabledPlugins` key in `settings.json` only flips a
switch; on a host that has never fetched the marketplace there is nothing to
switch on, so each plugin has to be installed explicitly. This step can fail and
**must never abort the run** — see the comment block at the step itself, which
records why.

The loop reads its specs from a **here-string, never a pipe**: a piped `while
read` runs in a subshell, and every `bad()` inside it would increment a `FAILURES`
that dies with that subshell — leaving `--check` exiting 0 on a host with no
plugins at all.

**4. Nothing.** This step used to be a symlink farm. It was removed; the numbers
below are unchanged so that step 5 and step 6 keep the names they have
everywhere else.

**5. Settings merge — key-level, never file replacement.**

```sh
jq -s '(.[0] * .[1]) | delpaths([$unset[] | split(".")])' <live> claude/settings.owned.json
```

Nineteen owned keys; everything else on the host is left alone. `split(".")` is
what lets `SETTINGS_UNSET` name a **nested** key: the entry
`hooks.PostToolUse` becomes the path `["hooks","PostToolUse"]`. The earlier
one-element form could only ever delete a top-level key, which is why the
retired hook bindings survived on every host. Entries are named individually
and never as a bare `hooks` — the `PreToolUse` entry beside them belongs to
another tool.

Two further properties are load-bearing:

- The merge writes to a temp file and `mv`s it, so an interrupted install can never
  leave a truncated `settings.json` behind.
- A `settings.json` that does not parse is reported and left **strictly alone**
  rather than overwritten. That is how a host loses every preference at once.

There is a canary: `hooks.PreToolUse` is snapshotted before the write and asserted
after it. See `docs/traps/PRETOOLUSE_HOOK_GONE_AFTER_INSTALL.md` for why.

**6. Shell exports.** `MAX_MCP_OUTPUT_TOKENS=500000` and
`CLAUDE_CODE_MCP_AUTO_BACKGROUND_MS=0`, appended inside a marked block to the login
shell's rc only (`.zshrc` / `.bashrc` / `.profile`, chosen from `$SHELL`). Most
hosts here have a `.bashrc` they never source, so requiring every rc file that
happens to exist would fail hosts for no reason.

`MAX_MCP_OUTPUT_TOKENS` is load-bearing, not cosmetic: without it large MCP results
are silently truncated, which reads as a broken tool rather than a missing export.

Exports already present *outside* the managed block are accepted as-is. Rewriting
someone's login shell behind their back is not worth the tidiness.

## What `--check` proves, and what it does not

It proves: every prerequisite is present, the memory import resolves, the
dispatcher is in place, every owned key still matches, every unset key is still
absent, and the shell exports are set.

It does **not** prove the host is running the version you think it is. `--check`
compares the host against whatever `install.sh` was invoked from, so a checkout
sitting on a stale commit or a feature branch passes cleanly while the host's
plugin cache holds something else entirely. That failure has been observed and
is written up in `docs/traps/CHECK_PASSES_ON_A_STALE_CLONE.md`. Establishing
that a host matches its published intent is the audit skill's job, not
`--check`'s.

## Two steps cannot be sandbox-tested

`rtk init -g` and `claude plugin install` both write to the real `~/.claude`
regardless of `$CLAUDE_CONFIG_DIR`. Everything else honours it, which is what makes
`./test-install.sh` safe to run on a live machine.

`test-install.sh` covers dry-run inertness, a fresh host with no `settings.json` at
all, idempotency across a second install, preservation of unowned keys and of rtk's
`PreToolUse`, refusal to overwrite malformed JSON, both drift shapes that `--check`
must catch, and the literal `@RTK.md` form.
