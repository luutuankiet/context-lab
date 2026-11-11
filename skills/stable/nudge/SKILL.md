---
name: nudge
description: "Start a 10-second background sleep so the session wakes itself after the user runs /compact. Use when the user invokes /nudge before compacting."
---

# Nudge

Call the Bash tool once, with `run_in_background: true`:

```sh
sleep 10
```

Then reply with exactly one line and nothing else:

```
⏳ nudge armed, run /compact now
```

No echo, no report, no footer. Context is already high when this runs.

When the sleep finishes and wakes you, carry on with the work that was in
progress before the compaction.
