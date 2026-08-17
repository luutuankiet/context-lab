# Context Lab

The lab where agent context is designed, and the package that ships it to every
host this operator works on. Bash and markdown; no build, no runtime.

## Hard constraints

- **`claude/` is the payload shipped to `~/.claude/`; `.claude/` configures agents
  working on this repo and ships nowhere.** One character apart — read the path
  twice before editing either.
- **What this repo emits into another repo carries no brand.** A repo laid out this
  way reads as ordinary good housekeeping, not a methodology to learn first.
- **Never a directory symlink into `~/.claude/`** — it holds `.credentials.json`,
  `history.jsonl` and twenty-odd runtime entries Claude Code owns. Link named files.
- **Key material is blocked by pattern, not path**, and an ignore line is inert
  against a file already tracked at HEAD. The repair is `git rm --cached`.
- **Write bash for the oldest interpreter in the fleet, 3.2**, under `set -euo
  pipefail`.

## Layout

```
AGENTS.md      always in context — keep it under 4 KB     CLAUDE.md  = @AGENTS.md
claude/        the payload installed onto every host      install.sh the distributor
skills/        stable | in-progress | deprecated          scripts/   repo tooling
docs/          prose, indexed in docs/README.md           .claude/   never shipped
```

Only `skills/stable/` installs. Moving a directory between buckets is a behaviour
change, not filing.

## Check commands

```sh
./install.sh --check              # this host's user tier; mutates nothing
./install.sh --dry-run            # print every mutation without performing it
./test-install.sh                 # assertions against a throwaway $HOME
scripts/gen-docs-index.sh --check # fail if docs/README.md is stale
```

No CI, no other test runner. Nothing runs these for you.

<!-- Standard block. Everything above belongs to this project; everything below is
     the pointer every repo laid out this way carries. -->

## Documentation

Indexed in [docs/README.md](docs/README.md). Every page is self-contained — it
assumes you opened that one file and have nothing else loaded.

| where | what | read it |
|---|---|---|
| [architecture/](docs/architecture/) | where behaviour lives, one page per area | before going looking for something |
| [traps/](docs/traps/) | failure modes with no error message, indexed by symptom | before debugging something wrong but not crashing |
| [reference/](docs/reference/) | simply true, expensive to re-derive | when you need the detail |
| [adr/](docs/adr/) | why the repo is the way it is | before changing something that looks odd |

## Before you wrap up

Leave the repo holding what this session cost you to find out. Four rules.

1. **Sort it, and expect most of it to go nowhere.** A next action is an issue. A
   durable, expensive-to-re-derive fact is a page. A hard-to-reverse choice with a
   rejected alternative is an ADR. Status, dates, version pins and plans are none of
   those — delete them.
2. **A doc is the last resort.** Type error → test → comment at the site → doc.
   Name the single line you would have commented instead; if you can name it,
   comment it and stop.
3. **Verify against running code before writing, and date the page `verified:`.**
   Anything remembered from earlier in the session is stale until re-read. Deleting
   a draft because the problem is already fixed is a success.
4. **Append, never rewrite.** Supersede a merged ADR with a new one naming what it
   replaces. A trap filename is an identifier quoted elsewhere: edit the body, never
   the name.

Then run `scripts/gen-docs-index.sh`. Never hand-maintain an index.
