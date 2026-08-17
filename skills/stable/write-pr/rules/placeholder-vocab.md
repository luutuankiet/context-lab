# Placeholder Vocabulary

Quick reference for write-pr template variables, globals, and filters.

## Globals (always in template scope)

| Name | Type | Source |
|---|---|---|
| `meta` | object | Frontmatter YAML, parsed |
| `load_json(path)` | function | Read + parse JSON from `<evidence_dir>/<path>` |
| `load_text(path)` | function | Read text from `<evidence_dir>/<path>` |
| `evidence_dir` | string | Absolute path to `--evidence` arg |

## Filters

### `md_table(data, columns?, align?)`
JSON array → markdown table.
- `columns`: explicit column order (default: auto-detect from first row, insertion order)
- `align`: 'L' | 'R' | 'C' global OR per-column `{col: Align}` (default: numeric cols R, others L)

```jinja
[[ rows | md_table ]]
[[ rows | md_table(columns=['name', 'count']) ]]
[[ rows | md_table(align={count: 'R', status: 'C'}) ]]
```

**Size heuristic:** fold tables with >10 rows via `[[ rows | md_table | fold('...') ]]`. See Trait 3a in `good-pr-traits.md` for full thresholds across all block types.

### `json_pretty(data, indent?, fold?, summary?)`
Value → fenced ```json block, optional `<details>` fold.
- `indent`: default 2
- `fold`: default false — wraps in `<details><summary>JSON</summary>...`
- `summary`: default 'JSON' — `<summary>` label when fold=true

### `gh_callout(type, text)`
- `type`: TIP | NOTE | IMPORTANT | WARNING | CAUTION (case-insensitive)
- `text`: body; multi-line gets `> ` prefix per line

```jinja
[[ 'TIP' | gh_callout('Schema change is backwards compatible.') ]]
```

**GOTCHA:** doesn't render styled inside `<details>` — see `callout-gotcha.md`.

### `delta_table(before, after, opts?)`
Two arrays of `{key, value}` rows → 4-col table (key / before / after / Δ).
- `opts.key`: join field. Default `'metric'`
- `opts.value`: value field. Default `'value'`
- `opts.precision`: decimals for numeric Δ. Default `2`
- `opts.percent`: show `(±N%)` next to numeric Δ when before ≠ 0. Default `true`
- `opts.key_label` / `before_label` / `after_label` / `delta_label`: override column headers

Δ semantics: both numeric → `+15 (+12%)`; missing side → `added` / `removed`; strings → `changed` if different, blank if same.

```jinja
[[ before_rows | delta_table(after_rows) ]]
[[ before_rows | delta_table(after_rows, {key: 'endpoint', value: 'p95_ms', percent: false}) ]]
```

### `code_expand(path, lines?, lang?, root_path?, annotate?)`
Read source file (relative to frontmatter.root_path) → fenced code block with `# <path>:<lines>` header.
- `lines`: 'N-M' or `[N, M]`; omit for whole file
- `lang`: override auto-detect (default: detected from extension)
- `root_path`: per-call override of frontmatter (or `evidence_dir` for self-contained examples)
- `annotate`: `{lineNum: 'note text'}` map; appends ` <comment> <- text` to the matching line

### `fold(content, summaryOrOpts?)`
Wrap any content in a `<details><summary>` block. Composable with every other filter.
- `summaryOrOpts`: string shortcut for the summary label, OR `{summary, open}` object
- `summary`: collapsed label. Default `'Details'`
- `open`: render expanded. Default `false`

```jinja
[[ long_text | fold ]]
[[ long_text | fold('Full log') ]]
[[ rows | md_table | fold(summary='Validation results', open=true) ]]
[[ payload | json_pretty | fold('Raw query result (JSON)') ]]
```

**NOTE:** `json_pretty(fold=true)` is still supported for back-compat, but prefer composing
with the `fold` filter — it works for any string, not just JSON output.

## Custom delimiters (MANDATORY)

| Default Jinja | write-pr | Reason |
|---|---|---|
| `{{ var }}` | `[[ var ]]` | Avoid dbt-Jinja collision in code fences |
| `{% if %}` | `[% if %]` | Same |
| `{# comment #}` | `[# comment #]` | Same |

See `template-gotchas.md` for the two edge cases that bite (`[[[ ... ]]]` and literal-filter-in-prose).
