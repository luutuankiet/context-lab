# Template Gotchas (custom delimiter edge cases)

write-pr uses `[[ ]]` for variables and `[% %]` for blocks (custom delimiters to dodge dbt-Jinja `{{ }}` collisions in code fences). This shifts the collision surface — here are the patterns that bite.

## Gotcha 1: `[[[ ... ]]]` triple-bracket trap

Looks like nested brackets; the parser sees variable-start + bad expression.

### Symptom

```jinja
- [[[ 'x' if checked else ' ' ]]] Item label
```

Nunjucks lexer sees `[[` (variable start), then content begins with `[`, then tries to parse `[ 'x' if checked else ' '` as an expression — fails with `unexpected token: [`.

### Workaround

Use `[% if %]` / `[% else %]` blocks that emit literal `[x]` / `[ ]`:

```jinja
- [% if checked %][x][% else %][ ][% endif %] Item label
```

The `[%` block-start is unambiguous (distinct from `[[` variable-start), and the block body is plain literal text.

This is exactly what `snippets/checklist.j2` does.

## Gotcha 2: Literal `[[ ... | filter ]]` in prose triggers eval

If you want to DOCUMENT a filter call in prose (e.g. "use `[[ foo | md_table ]]` to render a table"), the parser will try to evaluate `foo | md_table` at render time.

### Symptom

```jinja
The shorthand is [[ rows | md_table ]] which produces a markdown table.
```

At render time, `rows` is undefined → blank output (with `throwOnUndefined: false`) or error.

### Workaround A: prose paraphrase

Just say it in English:

```jinja
The shorthand is `rows | md_table` (pipe the array into the md_table filter)
which produces a markdown table.
```

### Workaround B: string-literal interpolation

Wrap the literal in a string-literal variable interpolation. The outer `[[ ]]` interpolates; the string content (with its own `[[ ]]`) emits unchanged.

```jinja
Use `[[ "[[ rows | md_table ]]" ]]` to render a table.
Use `[[ "[[ obj | json_pretty ]]" ]]` to render JSON.
```

Rendered: `` Use `[[ rows | md_table ]]` to render a table. ``

### Why NOT `[% raw %]`

Nunjucks `{% raw %}` / `{% endraw %}` does NOT work with custom delimiters. The raw-mode lexer hard-codes default `{% endraw %}` as the scanner target — it ignores the configured `blockStart` / `blockEnd`. With write-pr's `[% %]`, the parser sees `[% raw %]` as a regular block tag, then later trips on `[% endraw %]` with `unknown block tag: endraw`. Use the string-literal pattern above instead.

## Gotcha 3: `## heading` inside `<summary>` (HARD-LINTED at render)

A markdown heading placed inside a `<summary>` element looks like a clever way to make the section header double as the click-target. It is, in fact, the antipattern this skill explicitly fails on.

### Symptom

```jinja
<details><summary>

## Root cause

</summary>

...body...

</details>
```

On GitHub: the bold heading text IS the click-target. When collapsed (the default), reviewers see what looks like a normal `##` heading with no visible affordance that there's hidden content underneath. The heading also drops out of GitHub's anchor-link graph (no `#root-cause` jump link).

The render step lints for this and throws:

```
write-pr: heading-inside-<summary> antipattern detected (1 occurrence):
  - ## Root cause

Headings inside <summary> collapse the section title behind the click-target.
Move the heading OUTSIDE the <details> wrap; use "Click to expand details"
(or a descriptive label) as the <summary> text.
See rules/template-gotchas.md Gotcha 3 and rules/good-pr-traits.md Trait 3.
```

### Workaround

Keep `## heading` visible at the section level. Wrap only the body. Default summary text is `Click to expand details`; override with a descriptive label when it earns its keep.

```jinja
## Root cause

<details><summary>Click to expand details</summary>

...body...

</details>
```

For an evidence dump that warrants a more descriptive label:

```jinja
## Validation

<details><summary>Exhaustive 56-field audit</summary>

...table + analysis...

</details>
```

See `rules/good-pr-traits.md` Trait 3 for the full rule.

## Pre-render check

To catch undefined-variable silently-empty renders early, render to /tmp and grep:

```bash
write-pr render --template pr.md.j2 --evidence ./evidence --out /tmp/preview.md
rg -n '\[\[ ' /tmp/preview.md
# Expected: zero matches — any leftover `[[ ` means an unparsed variable
```
