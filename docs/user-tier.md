# The user tier

Everything under `claude/` is the Claude Code **user tier** — the config that is
the same on every host in the fleet. `install.sh` puts it on a host; `install.sh
--check` proves it is still there and still matches.

The project tier (a repo's own `CLAUDE.md`, `.claude/skills/`, `docs/`) is not
here and never installed. No repo carries `settings.json` or hooks.

## Why symlinks and not copies

An edit made on a host writes straight into the tracked file, so drift shows up
as `git status` output in the clone and the fleet-wide drift check is one
command:

```sh
git -C <clone> fetch -q && git -C <clone> status --porcelain=v1 -b
```

Copies make the same edit invisible. That is not hypothetical: joon's
`bc`→`awk` statusline fix was hand-applied there and went unnoticed on thinkpad
for weeks, and a copy-based re-install would have silently reverted it.

**Never a directory symlink.** `~/.claude/` also holds `.credentials.json`,
`history.jsonl`, `projects/`, `sessions/` and twenty-odd other runtime entries
that Claude Code owns. Linking the directory would commit secrets. `install.sh`
links three individual files and nothing else.

## `settings.owned.json`

Sixteen top-level keys, applied by a **key-level merge, never a file
replacement** — three `settings.json.ccr-backup-*` files on thinkpad prove other
tools write to this file too.

```sh
jq -s '.[0] * .[1]' ~/.claude/settings.json claude/settings.owned.json
```

Left host-local on purpose: `verbose`, `spinnerTipsEnabled`,
`promptSuggestionEnabled`, `terminalProgressBarEnabled`, `prefersReducedMotion`,
`voice`, `voiceEnabled`.

### `hooks` names only `UserPromptSubmit` and `PostToolUse`

`*` merges objects key-wise but **replaces arrays wholesale**. `rtk init -g`
owns `hooks.PreToolUse`, so naming `PreToolUse` in the manifest would erase
rtk's hook on every install. `install.sh` carries a canary that fails the run if
a pre-existing `PreToolUse` disappears across the merge.

### The unset list

A `jq` merge can add or change a key but never remove one, so removals need an
explicit list or a dead key survives on every host forever. Currently one entry:

- `enabledMcpjsonServers` — `["proxy"]`, a dangling reference to a `.mcp.json`
  server that no longer exists. The proxy is registered at the claude.ai account
  level, so a checkout needs no MCP config at all.

## `install.sh`

Six steps, in order. `--dry-run` prints every mutation without performing it;
`--check` verifies and mutates nothing.

1. **Prereqs.** Required: `jq awk sed git curl`. **`bc` is deliberately not
   required** — joon has never had it, and both consumers were moved to `awk`
   precisely so this installer never has to reach for a package manager. `gh` is
   also missing on joon; nothing in the user tier needs it.
2. **rtk — two commands, not one.** rtk's own `install.sh` writes only the
   binary and touches nothing under `~/.claude`. `rtk init -g --auto-patch` is
   what owns the harness surfaces, and `--auto-patch` is required because the
   default `PatchMode::Ask` blocks on stdin and hangs a non-interactive install.
   **Do not track `~/.claude/hooks/rtk-rewrite.sh` or `.rtk-hook.sha256`** —
   rtk's `migrate_old_hook_script()` deletes both by design.
3. **Marketplace plugin** — `mattpocock-skills@claude-plugins-official`. The
   `enabledPlugins` key only flips a switch; on a host that has never fetched
   the marketplace there is nothing to switch on.
4. **Symlink farm** — three files, plus `link-skills.sh` when the skills tree
   lands (a no-op until then).
5. **Settings merge** — temp file then `mv`, so an interrupted install can never
   leave a truncated `settings.json`. A `settings.json` that does not parse is
   reported and left strictly alone rather than overwritten.
6. **Shell exports** — `MAX_MCP_OUTPUT_TOKENS=500000` (load-bearing: without it
   large MCP results are silently truncated, which reads as a broken tool rather
   than a missing export) and `CLAUDE_CODE_MCP_AUTO_BACKGROUND_MS=0`. Only the
   login shell's rc is required — most hosts have a `.bashrc` they never source.
   Exports already present outside the managed block are accepted as-is;
   rewriting someone's login shell behind their back is not worth the tidiness.

### What `--check` catches

Prereqs, every link still resolving into the clone, every owned key still
matching, every unset key still absent, and the shell exports. The failure mode
it exists for is the blind spot every symlink farm has: **a link replaced by a
real file keeps working, so nobody notices the host has stopped tracking.**

## Landmines

- **`CLAUDE.md` must import `@RTK.md` — relative, bare, and left exactly as
  `rtk init -g` writes it.** Rewriting it to the absolute `@~/.claude/RTK.md`
  looks safer and breaks the install: rtk detects its own reference by the
  **literal string** `@RTK.md`, does not find it inside `@~/.claude/RTK.md`, and
  appends a second import — writing *through* the symlink into the tracked file,
  so every fresh host dirties the clone. `RTK.md` itself is written by
  `rtk init -g` and is deliberately not tracked here.

  The ambiguity that motivated the absolute form does not exist. **Measured on
  thinkpad, not inferred:** with `~/.claude/CLAUDE.md` symlinked into this clone,
  a probe file placed only in `~/.claude/` — and deliberately absent from the
  link target's directory — resolved. **A relative `@import` resolves against
  the link's directory, not the link target's.** `test-install.sh` asserts the
  bare form so this cannot regress silently.
- **Two steps cannot be sandbox-tested.** `rtk init -g` and `claude plugin
  install` both write to the real `~/.claude` regardless of
  `$CLAUDE_CONFIG_DIR`. Everything else honours it, which is what makes
  `test-install.sh` safe to run on a live machine.
- **`statusline.sh` and `token-tracker.sh` are byte-compatible across the fleet
  only because both use `awk`.** Re-introducing `bc` anywhere silently breaks
  joon: the statusline fails per-render and nobody sees an error.

## Testing

```sh
./test-install.sh            # 29 assertions against a throwaway $HOME
./install.sh --check         # verify this host
```

`test-install.sh` covers dry-run inertness, a fresh host with no `settings.json`
at all, idempotency across a second install, preservation of unowned keys and of
rtk's `PreToolUse`, refusal to overwrite malformed JSON, and both drift shapes
(`--check` catching a de-linked file and a hand-edited owned key).
