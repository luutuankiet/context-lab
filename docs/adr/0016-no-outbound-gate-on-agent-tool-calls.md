# No outbound gate on agent tool calls

The plugin shipped a `PreToolUse` hook, matcher `Bash|mcp__.*gh-cli__.*`, that piped
every agent command and GitHub MCP call to `envscan gate` and denied any that would
publish a known `.env` value. It is removed, with its shim and its tests.

**What this repo ships for sanitizing is a program and a workflow:** `envscan`, and
the promote-tmp skill that moves `tmp/` files into committed pages and evidence with
every value replaced by a `$KEY` and every copy scanned clean. Checking each agent
tool call is a different product, and it brought costs the workflow does not need:

- every GitHub MCP write is denied on a host where `envscan` is missing;
- whether a plugin hook fires on `!` commands and holds under `bypassPermissions`
  is unverified, so the gate's coverage could not be stated;
- a hook binding goes live on every host at the next `claude plugin update`,
  including for colleagues who never asked for it.

## What stays

- `envscan gate` in the binary, and the git `pre-push` hook that the promote-tmp
  skill installs with `envscan gate install` in a repo that has `.env`. It refuses a
  push carrying a known value, or one made while a key in `.env.example` has no
  value. It is a git hook, runs only where the skill put it, and is the last check
  before anything leaves the machine.
- `envscan scan` before every commit the skill makes.

## Considered options

- **Keep the gate.** Rejected: see the costs above.
- **Also drop `pre-push`.** Rejected: a page that slips past the skill's scan would
  then have no check at all on its way out.

## Consequences

An agent's issue or pull request text is no longer checked by any hook. The rule
that published text names a sensitive thing by a bare `$KEY` stands, and is now
enforced by the writer and by `envscan scan`, not by a gate.
