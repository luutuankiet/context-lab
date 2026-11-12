---
name: nudge
description: "Start a background sleep for auto resume after compaction"
disable-model-invocation: true
---

# Nudge

Call the Bash tool once, with `run_in_background: true`:

```sh
sleep 20
```

**After the tool call just reply "ok" nothing else. No prose. literal "ok" stop the turn. No exceptions**.
