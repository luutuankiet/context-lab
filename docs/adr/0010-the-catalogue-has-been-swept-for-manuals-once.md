# The catalogue has been swept for manuals once, and holds none

[ADR 0009](0009-a-tools-manual-lives-in-the-tools-repo.md) gave the rule and moved
the two skills that prompted it. It did not sweep the rest of `skills/stable/`.
That sweep has now happened, so the question is settled for every directory in
the bucket rather than for the ones someone happened to look at.

Two more moved:

| skill | authoring repo | what it documents |
|---|---|---|
| `looker-mcp-shim` | `luutuankiet/looker-mcp-shim` | the npm MCP server of the same name |
| `slides-mcp` | `luutuankiet/slides-mcp` | the PyPI MCP server of the same name |

Six were examined and stay, because none of them documents a tool: `mcp-dev`
(already argued in 0009), `github-clone-research`, `handoff-loop`,
`long-running-jobs`, `release`, `repo-context-audit`. Each is a loop this
operator works in, and none has a repository of its own to move to.

**`skills/stable/` now holds no tool manuals.** A future sweep is re-derivation,
not diligence.

## Both copies were behind, and one hid it well

0009 recorded a copy that had drifted *ahead* of upstream, and its hunk was
pushed up before deletion. These two drifted the other way, and neither emitted
anything.

`slides-mcp` was upstream's `docs/slides-api-cookbook.md`, byte for byte, minus
three lines that a release had added: a mandate blockquote, a write-scope OAuth
tip, and a link to `releases/v2.1.0.md`. That last line is the argument in
miniature — a relative link into `releases/` only resolves in the repo that has
a `releases/`.

`looker-mcp-shim` was a whole feature release behind: no `rules/visual-preview.md`,
no `render_dashboard` / `render_tile` / `get_render` rows, no capability bullet.
Nothing was authored here that upstream lacked, so nothing needed pushing up —
the diff is a strict subset once the example ids are set aside.

## Why upstream's real ids were accepted over the scrubbed copy

The vendored `looker-mcp-shim` was not a plain copy. Every example identifier had
been replaced — dashboards, tiles, filters, and the LookML model and view names —
with invented ones. Pointing at upstream discards that scrubbing.

Rewriting upstream to match was the alternative, and it was rejected. The
scrubbing protects nothing that is not already public: the authoring repo carries
those ids in its own public history, so a pointer discloses strictly less than
that repo already does. Nothing in the skill trips this repo's disclosure bar —
no credentials, no cloud project ids, no account emails, no absolute home paths,
no fleet endpoints, and `host` appears only as a literal placeholder. What is
gained is a manual whose examples resolve against a real instance.

The scrubbing also has a cost that only shows up later: it makes every future
`diff` against upstream unreadable, which is how a whole missing feature block
went unnoticed.

## Two install routes now reach one skill

`looker-mcp-shim` ships an `install-skill` subcommand that recursively copies its
skill directory into a Claude Code skills folder. It is untouched and still
serves people who use the shim without this marketplace.

This is not the failure 0009 records. Both routes serve the same bytes from the
same repo, so they cannot drift apart — only a hand-maintained second copy can.
Installing by both on one machine would load the skill twice, once bare and once
namespaced; pick one per machine.
