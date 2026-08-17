# `claude/` — the distributed user tier

**This directory is the payload.** `install.sh` links its contents into
`~/.claude/` on every host in the fleet.

**It is not this repo's own harness config.** That lives one directory up, in
`.claude/` — with a leading dot. The two names differ by a single character and
conflating them is how the lab's own scaffolding leaks onto every host.

| you are editing | if you want to change |
|---|---|
| `claude/` (here) | what every host gets |
| `../.claude/` | how agents behave when working *on Context Lab* |

## Contents

| file | role |
|---|---|
| `CLAUDE.md` | user-tier memory — applies in every repo, on every host |
| `settings.owned.json` | the keys Context Lab owns; merged key-level into `~/.claude/settings.json` |
| `statusline.sh` | linked to `~/.claude/statusline.sh` |
| `hooks/token-tracker.sh` | linked to `~/.claude/hooks/token-tracker.sh` |

## Two rules that bit before

1. **Never a directory symlink.** `~/.claude/` also holds `.credentials.json`,
   `history.jsonl`, `projects/`, `sessions/` and 25+ other runtime entries.
   Link per file.
2. **Settings merge is key-level, never file replacement.** A `jq` merge can add
   or change a key but can never *remove* one — anything that must be unset
   needs an explicit delete or it survives on every host forever.
