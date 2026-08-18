# Context Lab

The lab where agent context is designed, and the package that ships it to every
host in the fleet.

**No clone required.** `marketplace add` fetches the whole repository for you, so
all three commands are typed as-is:

```sh
claude plugin marketplace add luutuankiet/context-lab
claude plugin install context-lab@context-lab
~/.claude/plugins/marketplaces/context-lab/install.sh
```

**The third command is the one nothing will remind you about.** The first two give
you the skills; the plugin model has no post-install step of any kind, so the
config tier — statusline, hooks, settings, the user-memory import — is applied only
by running the installer out of the fetched clone. There is no credential to put on
a machine.

Then keep it current. `marketplace update` re-fetches the repository and is what
makes both skills *and* user memory current; re-running the installer re-applies
the config tier:

```sh
claude plugin marketplace update context-lab
~/.claude/plugins/marketplaces/context-lab/install.sh
~/.claude/plugins/marketplaces/context-lab/install.sh --check   # verify, mutate nothing
```

Developing on it instead? Clone it anywhere you like and run that clone's
`install.sh`; only the two linked config files follow the clone, while user memory
always imports from the marketplace copy.

## What is in here

| tree | role | who reads it |
|---|---|---|
| `claude/` | the **payload** — user-tier config installed into `~/.claude/` | every host, via `install.sh` |
| `skills/` | the **distributed** skills collection — `stable/` ships as the `context-lab` plugin | every host, via `install.sh` |
| `install.sh` | the distributor — links config, installs plugins | you, once per host |
| `.claude-plugin/` | the marketplace and plugin manifests | Claude Code, on install |
| `docs/` | the lab's own writing | humans, and agents on demand |
| `AGENTS.md`, `CLAUDE.md`, `.claude/` | **this repo's own** harness config | agents working *on* Context Lab |

## The one structural requirement

> Two trees must stay unambiguous: what Context Lab uses to **maintain itself**
> versus what it **distributes**. Otherwise the lab's own scaffolding leaks into
> every repo it touches.

The cut is the leading dot — `.claude/` configures agents working on this repo and
ships nowhere; `claude/` is the payload. ⚠️ One character. Read the path twice
before editing either. Why it was cut there:
[ADR 0001](docs/adr/0001-two-trees-cut-on-the-leading-dot.md).

## The naming rule

*Context Lab* names the lab. **What it emits into any other repo carries no brand at
all** — a canonical shape any agent reads as "this repo is laid out well," not a
methodology to learn first. If you find the string "Context Lab" inside a file
destined for another repo, that file is wrong.

## Documentation

Start at **[AGENTS.md](AGENTS.md)** — it is what an agent loads, and it is short
enough to read in a minute.

Everything else is indexed in **[docs/README.md](docs/README.md)**: how the
installer works, the traps that have already cost somebody an afternoon, the
reference detail, and the decisions behind the shape.
