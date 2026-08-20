---
name: dumb-down
description: guided reading for the user in order to understand a concept
argument-hint: "here's my rubber duck..."
disable-model-invocation: true
---

# Walk it, do not summarise it

Render every artifact as a **banded gutter block** followed by an **annotation
table**. Show the thing, then say what each line means. Explain only lines that
are on screen.

## Cold reader, no tabs

The reader has seen none of your tool results and will open nothing. Every file,
command output, config entry and commit message the answer rests on gets pasted
in full. "As shown above in the JSON" is a failure — paste the JSON. Never
reference a line the reader cannot see in the same message.

## The shape

Band, gutter block, table, verdict. Band top **and** bottom, so the boundary
between your prose and the artifact is unmissable.

**━━━ 📄 `~/.claude/hooks/example-card.sh` · 28 lines ━━━**

```text
 9│ BIN=""
10│ ROOT="…/plugins/cache/context-lab/learn-with-feedback-loop"
11│ if [ -n "$ROOT" ] && [ -d "$ROOT" ]; then
   │ …
13│   for c in "$ROOT"/*/skills/learn/bin/session-card.sh; do
14│     [ -x "$c" ] || continue
15│     if [ "$c" -nt "$newest" ]; then newest="$c"; fi
16│   done
17│   [ -n "$newest" ] && BIN="$(dirname -- "$newest")"
18│ fi
19│ [ -n "$BIN" ] || BIN="…/learn-with-feedback-loop/741a3fa7f128/…/bin"
```

**━━━ end 📄 example-card.sh ━━━**

| 📍 | what it means |
|---|---|
| **L10** | Frozen at install time, but **version-free** — it names the folder that holds every version, not any one of them. |
| **L14** | Drops cached versions with no card. Four of the nine die here. |
| **L15** | **The selection key.** `-nt` compares file timestamps, not versions. Every defect below traces to this operator. |
| **L17–L19** | L17 fills `BIN`; L19 is `\|\|`, an **else branch**, so it never runs. The hash is unreachable. |

> One verdict, directly under the table, naming what this block proves.

## Rules

**The fence.** Always ` ```text `, never a language tag. Syntax highlighting and
a gutter are mutually exclusive, and the line numbers won the trade — the reader
needs to point at a line more than they need colour.

**The gutter.** Real line numbers from the file, never renumbered from 1. A
block quoting lines 194–243 opens at `194│`. The reader must be able to run
`sed -n '194,243p'` and get the same text.

**Elision.** A gutter-less `   │ …` line. Nothing else — no "6 more comment
lines", no summary of what was cut. That is noise; the gap itself is the signal.
Elide inside a long token with `…` too. Every literal is real: truncate a path,
never invent, reword or tidy one.

**The band.** Kind marker, identifier, size. `📄` file, `💾` disk listing, `🔀`
git, `$` shell. Close with `**━━━ end 📄 <short name> ━━━**`.

**The table.** Two columns. Anchor with a bold **L<n>**; a range like
**L17–L19** when the point is a relationship between lines. Escape `|` as `\|`
inside cells. A row only for lines that carry something — a row per line is
noise. Never put a fenced block or `<br>` in a cell; both break the renderer.

**Size.** Width ≤ 78. A block of 6–20 lines; longer, elide the middle or split
it and narrate between the halves.

**Claiming a defect.** Run it and show the values, one row per step, before
asserting anything. A trace outranks an argument. When two sources disagree,
show both and prove which is stale with a command.

## Do not

These were tried and rejected — do not reintroduce them.

| tried | why it lost |
|---|---|
| Language-tagged fence for highlighting | Kills the gutter; the reader loses the ability to say "line 19". |
| `# 📍 L19` markers inside the code | Puts your words in their file, and the block stops being verbatim. |
| `<br>`-joined snippets in a table cell | Renders as one broken run in a terminal UI. |
| One mini-snippet per annotation, `grep -C1` style | 2.5× longer, and re-shows the same lines repeatedly. |
| Footnote markers `(1)`, `(2)` in the code | Same problem as 📍 — the artifact is no longer what is on disk. |

## Done when

Every fragment the answer rests on has appeared in a banded gutter block and
been annotated, and a reader who opened nothing else could follow the whole
path from the first artifact to the verdict.
