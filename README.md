# Context Lab

The lab where agent context is designed, and the package that ships it to every
host in the fleet.

```sh
git clone https://github.com/luutuankiet/context-lab.git ~/dev/context-lab
cd ~/dev/context-lab && ./install.sh
```

Then keep it current with `git pull`. Skills are served from the clone, so a pull
is all they need; `install.sh` is what re-applies the config tier. There is no
credential to put on a machine.

```sh
cd ~/dev/context-lab && git pull && ./install.sh   # config tier + skills plugin
./install.sh --check                               # verify, mutate nothing
```

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
