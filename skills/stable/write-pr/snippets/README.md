# write-pr snippets

Reusable PR-section fragments. Each `.j2` file is a worked example of a
common section pattern observed in real refactor / perf / migration PRs.

## Usage modes

### Mode 1: Copy-paste (recommended for most agents)

1. Open the snippet that fits your section.
2. Copy the body (everything below the `[# ... #]` doc header).
3. Paste into your `pr.md.j2`.
4. Replace variable refs (`[[ tldr_rows ]]`, etc.) with literal data or `load_json` calls.

### Mode 2: Include (power users)

`renderPR` searches for `.claude/skills/write-pr/snippets/` walking up from the
template's directory. When found, snippets become reachable via `[% include %]`:

```jinja
[% set tldr_rows = load_json('queries/q_summary.json').rows %]
[% include 'snippets/tldr_kv_table.j2' %]
```

The set+include pattern lets you reuse a snippet body across PRs without
duplicating the markdown structure.

## Snippet index

| Snippet | When to use | Filters used |
|---|---|---|
| `narrative_tldr.j2` | 4-paragraph executive narrative ABOVE the metrics table — see Trait 8 | — |
| `tldr_kv_table.j2` | Top-of-PR 2-col metrics summary | `md_table` |
| `manifest_tip_header.j2` | TIP callout + ticket link | `gh_callout` |
| `before_after_img_table.j2` | 2-col before/after screenshots | — |
| `before_after_code.j2` | Stacked before/after code blocks | — |
| `design_decision.j2` | Options table + chosen + rationale | `md_table` |
| `numbered_validation.j2` | `### N. <Title>` validation sub-section | — |
| `mermaid_flowchart.j2` | Inline mermaid block skeleton (pure markdown, no filter dep) | — |
| `sql_appendix.j2` | Q-numbered SQL block w/ file:line header | `code_expand` |
| `delta_table_perf.j2` | Before/after comparison (perf, config migration, schema diff) | `delta_table` |
| `checklist.j2` | Bottom-of-PR reviewer checklist | — |

## Variable contract convention

Each snippet's `[# ... #]` doc header lists the variables expected in template
scope. Be explicit — prefer `[% set foo = ... %]` immediately above the
`[% include %]` so the next reader sees the contract inline.
