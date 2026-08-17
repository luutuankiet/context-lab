# Frontmatter `root_path`

`root_path` in the template's YAML frontmatter tells `code_expand` where to resolve relative source-file paths.

## Example

```yaml
---
title: "Refactor orders_intermediate: 96% wall reduction"
root_path: "/repos/acme-analytics"
---
```

```jinja
[[ 'models/intermediate/orders_intermediate.sql' | code_expand(lines='120-185') ]]
```

Resolves to: `/repos/acme-analytics/models/intermediate/orders_intermediate.sql:120-185`.
Rendered header: `# models/intermediate/orders_intermediate.sql:120-185`.

## Why a separate field

PRs are often drafted in a nested work directory (`<repo>/tmp/projects/<project>/pr.md.j2`). The reviewer expects file paths shown RELATIVE TO THE REPO ROOT, not relative to the work dir.

`root_path` lets you draft anywhere while keeping citations canonical.

## Without `root_path`

`code_expand` falls back to `process.cwd()`. Path headers will be relative to wherever `npx write-pr render` was invoked from. Usually fine for dev / one-offs; brittle for shareable templates.

## Per-call override

`code_expand(root_path='/other/root')` overrides the frontmatter default for that one call. Useful when one PR spans multiple repos.

`code_expand(root_path=evidence_dir)` is the standard pattern for self-contained examples — the source file lives next to the evidence, not in a separate repo. See `examples/minimal/pr.md.j2`.

## Absolute paths

`code_expand` accepts absolute paths and renders the header as RELATIVE TO `root_path`:

```jinja
[[ '/repos/acme-analytics/models/foo.sql' | code_expand(lines='1-5') ]]
```

Header: `# models/foo.sql:1-5` (assuming frontmatter root_path matches).
