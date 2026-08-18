---
title: The user-tier installer
covers: how a host gets its Claude Code config, what install.sh actually writes, and what --check can and cannot prove
verified: 2026-08-17
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

## The design is symlinks, not copies

`install.sh` links three individual files out of the clone:

| repo path | lands at |
|---|---|
| `claude/CLAUDE.md` | `~/.claude/CLAUDE.md` |
| `claude/statusline.sh` | `~/.claude/statusline.sh` |
| `claude/hooks/token-tracker.sh` | `~/.claude/hooks/token-tracker.sh` |

The manifest is the `LINKS` array at the top of `install.sh`, written as
`<repo path>|<claude path>`.

An edit made on a host writes straight through the link into the tracked file, so
drift is visible as ordinary `git status` output in the clone:

```sh
git -C <clone> fetch -q && git -C <clone> status --porcelain=v1 -b
```

Copies make the same edit invisible instead. That is not hypothetical — a
statusline fix hand-applied on one host went unnoticed on another for weeks, and a
copy-based re-install would have silently reverted it.

**Never a directory symlink.** `~/.claude/` also holds `.credentials.json`,
`history.jsonl`, `projects/`, `sessions/` and twenty-odd other runtime entries that
Claude Code itself owns. Linking the directory would put all of that in git.

## Six steps, in order

**1. Prerequisites.** Hard requirements are `jq awk sed git curl`. Wanted but never
fatal: `flock sha256sum node gh rg`. `bc` is *deliberately* absent from both lists —
one host in the fleet has never had it, and both consumers (`statusline.sh`,
`token-tracker.sh`) were moved to `awk` precisely so this installer never has to
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

**4. Symlink farm.** The three links above, and nothing else. Skills are not
linked and never will be: they arrive as the plugin from step 3.

**5. Settings merge — key-level, never file replacement.**

```sh
jq -s '(.[0] * .[1]) | delpaths([$unset[] | [.]])' <live> claude/settings.owned.json
```

Sixteen owned keys; everything else on the host is left alone. Two properties are
load-bearing:

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

It proves: every prerequisite is present, every link still resolves into the clone,
every owned key still matches, every unset key is still absent, and the shell
exports are set.

It does **not** prove the clone is the right clone. `--check` compares the host
against whatever is checked out, so a clone sitting on a stale commit or a feature
branch passes cleanly while the host runs something other than `main`. That failure
has been observed and is written up in
`docs/traps/CHECK_PASSES_ON_A_STALE_CLONE.md`.

## Two steps cannot be sandbox-tested

`rtk init -g` and `claude plugin install` both write to the real `~/.claude`
regardless of `$CLAUDE_CONFIG_DIR`. Everything else honours it, which is what makes
`./test-install.sh` safe to run on a live machine.

`test-install.sh` covers dry-run inertness, a fresh host with no `settings.json` at
all, idempotency across a second install, preservation of unowned keys and of rtk's
`PreToolUse`, refusal to overwrite malformed JSON, both drift shapes that `--check`
must catch, and the literal `@RTK.md` form.
