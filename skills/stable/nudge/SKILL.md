---
name: nudge
description: "Start a background sleep for auto resume after compaction"
disable-model-invocation: true
---

# Nudge

Call the Bash tool once, with `run_in_background: true` and the description
`nudge sleep`:

```sh
sleep 20
```

**After the tool call just reply "ok" nothing else. No prose. literal "ok" stop the turn. No exceptions**.

## When the sleep finishes

Its result arrives later as a background-task notification whose summary names
`nudge sleep`, often right after a compaction. That turn gets the same reply:
the literal word `ok`, nothing else.

This overrides everything else that turn would normally ask for: a hook asking
for a rollup ("ROLLUP CHECK"), the idle-rollup rule in memory, the echo, a
status line or context footer, and any tool call. The sleep exists only to wake
the session; there is nothing to report about it.
