---
title: The owned settings keys
summary: which nineteen keys install.sh takes over, which are deliberately left to the host, and which are actively deleted
verified: 2026-08-18
---

# The owned settings keys

`claude/settings.owned.json` is the manifest. `install.sh` merges it key-level into
`~/.claude/settings.json` — it never replaces the file, because other tools write
there too. Anything not listed here is the host's business.

The values live in the manifest and are not repeated here. What is expensive to
re-derive is *why each key is owned*, and that is what this page holds.

## Owned — nineteen keys

| key | why it is fleet-wide |
|---|---|
| `permissions` | `defaultMode: bypassPermissions` plus a six-entry deny list. The deny list is a **noise filter, not a sandbox** — it mutes tool surfaces that are not wanted, and it must never be confused with the blocked-tool list an earlier setup used to force filesystem work through a proxy. |
| `hooks` | Only `UserPromptSubmit` and `PostToolUse`, both pointing at `token-tracker.sh`. Naming a third event is dangerous — see `docs/traps/PRETOOLUSE_HOOK_GONE_AFTER_INSTALL.md`. |
| `statusLine` | The shared statusline, one tracked script for the whole fleet. |
| `effortLevel` | A working preference that should not vary by which machine you sat down at. |
| `outputStyle` | Same. |
| `enabledPlugins` | Flips the upstream skills plugin on. It only flips a switch — the plugin still has to be *installed*, which is `install.sh` step 3. |
| `cleanupPeriodDays` | 365. The default discards transcript history far sooner, and the history is the raw material for measuring what any of this costs. |
| `autoCompactEnabled` | Off. Compaction is driven deliberately, not by a threshold. |
| `autoMemoryEnabled` | Off. Memory that writes itself is a second store of truth, which is the failure this whole layout exists to undo. |
| `remoteControlAtStartup` | On. |
| `fileCheckpointingEnabled` | Off — git is the checkpoint. |
| `skipDangerousModePermissionPrompt` | Consequence of `bypassPermissions`; without it every session opens on a prompt. |
| `skipAutoPermissionPrompt` | Same. |
| `autoScrollEnabled` | Terminal behaviour that should be identical everywhere. |
| `agentPushNotifEnabled` | On. |
| `tui` | `fullscreen`. |
| `showThinkingSummaries` | On. Thinking is hidden in an interactive session unless this is set, and `Ctrl+O` transcript mode — the manual alternative — cannot be configured fleet-wide, which is the whole reason this is owned rather than left to the host. |
| `verbose` | On. With `showThinkingSummaries`, this is what makes thinking render in full in the main view instead of a collapsed one-liner. **It was previously host-local**; it moved because the pair only works together, and half the pair is not worth owning. It changes more than thinking output — that was accepted knowingly. |
| `extraKnownMarketplaces` | Registers this repo's own marketplace, so the plugin `enabledPlugins` flips on is resolvable. Only the public marketplace can live here: a private one names a repository a public consumer cannot fetch, and their install would fail. |

**`bypassPermissions` is fleet-wide, and the consequence is stated rather than
buried: there is no permission gate on any host, including a work machine.** That
was decided knowingly. A per-repo permission boundary was rejected because the
granularity has never once been exercised, and a tier with no job is a drift
generator.

## Deliberately host-local

Never merged, never checked, never reported as drift:

`spinnerTipsEnabled`, `promptSuggestionEnabled`,
`terminalProgressBarEnabled`, `prefersReducedMotion`, `voice`, `voiceEnabled`

These are how one machine feels to sit at. Standardising them buys nothing.

`verbose` used to sit in this list and no longer does — see the owned table above
for why. The reasoning that put it here was sound in isolation and wrong in
company: it is a rendering preference, but it is also the second half of the
thinking-output pair, and owning only the first half renders nothing.

## Actively unset

A `jq` merge can add or change a key but **can never remove one**, so a key that
should die needs an explicit removal list or it survives on every host forever.
`install.sh` carries that list as `SETTINGS_UNSET`.

| key | why it is deleted |
|---|---|
| `enabledMcpjsonServers` | Was `["proxy"]` — a dangling reference to a `.mcp.json` server that no longer exists. The MCP proxy is registered at the account level now, so a checkout needs no MCP config at all. |
| `agent` | Pinned a default agent file at user tier. On at least one host it resolved to a fork sitting in no git repo, so no amount of tidying a *repo* would ever have reached it. |

## Unowned keys are silent divergence

This is the honest limit of the design. `--check` verifies that every *owned* key
matches. A key nobody owns can hold anything, on any host, and `--check` still
reports the tier healthy — one host was found running a different model that way,
alongside legacy hook entries and dead files from a retired setup.

The installer also **never upgrades what it finds**. A host several releases behind
on the CLI, or on rtk, passes `--check` cleanly. `--check` is a *conformance* test,
not a freshness test; freshness is `docs/traps/CHECK_PASSES_ON_A_STALE_CLONE.md`.
