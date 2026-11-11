---
name: nudge
description: "Start a 10-second background sleep so the session wakes itself after the user runs /compact. Use when the user invokes /nudge before compacting."
disable-model-invocation: true
---

# Nudge

Call the Bash tool once, with `run_in_background: true`:

```sh
sleep 10
```