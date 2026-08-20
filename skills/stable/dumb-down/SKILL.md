---
name: dumb-down
description: guided reading for the user in order to understand a concept
argument-hint: "here's my rubber duck..."
disable-model-invocation: true
---

# Walk it, do not summarise it

Render every fragment as a **gutter block** followed by an **annotation table**.
Show the code the reader needs, then say what each line means. Explain only lines
that are on screen.

## The shape

```text
━━━━━━━━━━ what this fragment is ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 1│ ROOT="…/cache/context-lab/learn-with-feedback-loop"
 2│ for c in "$ROOT"/*/skills/learn/bin/session-card.sh; do
 3│   [ -x "$c" ] || continue
 4│   if [ "$c" -nt "$newest" ]; then newest="$c"; fi
 5│ done
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

| line | meaning |
|---|---|
| `1` | Frozen at install. Safe — the cache root keeps its name. |
| `2` | `*` sweeps all nine cache dirs; five contain the script. |
| `4` | `-nt` compares file timestamps, not versions. **The defect.** |

> One verdict, directly under the table, naming what this block proves.

## Rules

- Fence as ` ```text `, never a language tag: the band and gutter must render
  literally rather than as syntax.
- Width ≤ 62. Elide **inside** a long token with `…`. Every literal is real —
  truncate a path, never invent or reword one.
- Annotate by line number in the table. The code stays as it is on disk.
- Give a row only to lines that carry something. A row per line is noise.
- Keep a block to 4–12 lines. Longer, split it and narrate between the halves.
- One `>` verdict per block, immediately below its table, so the claim sits
  against its evidence.
- Claiming a defect: run it and show the values, one row per step, before
  asserting anything. A trace outranks an argument.

## Done when

Every fragment the answer rests on has appeared in a gutter block and been
annotated, and a reader who opened nothing else could follow the whole path.
