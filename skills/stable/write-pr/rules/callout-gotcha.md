# GitHub Callout Gotcha

`> [!TIP]` / `[!NOTE]` / `[!IMPORTANT]` / `[!WARNING]` / `[!CAUTION]` render as styled callout blocks on github.com... **but only OUTSIDE `<details>`**.

## The gotcha

```markdown
<details><summary>Click to expand</summary>

> [!TIP]
> This will NOT render as a styled callout.
> GitHub treats it as plain quoted text inside <details>.

</details>
```

Result: the `> [!TIP]` line shows literally as `> [!TIP]` text, not a callout. Same for the other 4 types.

## Why

GitHub's callout extension is implemented at the block-paragraph parsing layer. Content inside `<details>` is treated as a single HTML block by the markdown parser, so the callout extension never inspects it.

## The fix

**Put callouts OUTSIDE `<details>`**, before or after:

```markdown
> [!TIP]
> The styled callout renders here.

<details><summary>Details</summary>

Regular markdown body here. No styled callout inside.

</details>
```

## Pattern

The `manifest_tip_header.j2` snippet enforces this — TIP callout, then ticket link, then any folded `<details>` sections follow below.

## What still works inside `<details>`

| Element | Renders inside? |
|---|---|
| Headers (`##`, `###`) | ✅ yes |
| Tables | ✅ yes |
| Fenced code blocks | ✅ yes |
| Mermaid diagrams | ✅ yes |
| Bold / italic / lists | ✅ yes |
| Images (`<img>`) | ✅ yes |
| Plain block quotes (`> text`) | ✅ yes (just no callout styling) |
| GitHub callouts (`> [!TYPE]`) | ❌ NO — plain quote only |


## Interaction with Trait 3 (`rules/good-pr-traits.md`)

If you're following Trait 3 (each `##` heading stays visible at the section level + the section body is wrapped in `<details>`), any callout that conceptually announces the section must be placed BEFORE the `<details>` opens — typically right after the `##` heading and before the `<details>` block. Inside `<details>` the callout renders as plain quoted text. Place callouts at the TOP of the PR, right under section headings, or between section wraps — never inside one.
