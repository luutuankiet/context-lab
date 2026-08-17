# Private Notation — Pre-Render Grep Checklist

write-pr is for PUBLIC pull requests. Your private filing system (session log IDs, internal task IDs, work-doc references) MUST NOT appear in the rendered PR.

## The check

Run this BEFORE pasting PR.md into GitHub:

```bash
rg -n '\bLOG-[0-9]|\bTASK-[0-9]|WORK\.md|gsd-lite/' PR.md
# Expected: zero matches
```

If you see hits, fix them by **inlining the evidence** the citation was pointing at. Don't reword to hide the citation — paste the actual finding.

## What counts as private notation

| Token | Why private |
|---|---|
| `LOG-NNN` | Session log ID — only the agent's filing system understands these |
| `TASK-NNN` | Task ID — same |
| `WORK.md` / `WORK.md §N` | Session journal — reader has no index for it |
| `gsd-lite/` | Whole directory path is private — usually gitignored |
| `<your private session journal>:LNN` | Direct file:line into a private doc |

## What's NOT private notation (keep these)

| Token | Why OK |
|---|---|
| Git commit SHAs | Reproducible identifier |
| BQ job IDs | Reproducible — but check if URL leaks identity (see below) |
| CI run IDs / URLs | Reproducible identifier |
| `file:line` in REPO source | Reviewable identifier |
| Model names from public docs | Public reference |

## Identity / client info — different problem, same defense

If you're writing about client work that's going to a PUBLIC repo (e.g. an OSS tool that shipped from a client project), ALSO scrub:

| Pattern | Substitute |
|---|---|
| Client / vendor names | Generic placeholders (e.g. "Acme Corp") |
| Internal dataset names | Synthetic equivalent |
| Internal table / schema names | Synthetic |
| Production URLs revealing identity | Synthetic |
| Account / user names | Anonymized |

## Worked example

> ❌ Before: *"See LOG-007 for the natural-control technique; LOG-008 has the 53-field audit (WORK.md line 1474)."*
>
> ✅ After: *"We used a natural-control technique — waited 28min for a fresh prod build with no upstream rebuild between, so dev + prod consumed identical upstream state. Then ran an exhaustive 53-field audit: 45/48 fields zero-drift, 3 drifts traced to pre-existing antipatterns at `models/intermediate/orders_intermediate.sql:160 / :768 / :776`."*

Same information, zero private tokens — reviewer can act on it without grep'ing files they can't see.
