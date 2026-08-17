# Disk Convention

write-pr expects a specific `evidence/` layout (relative to your `pr.md.j2`):

```
<pr-work-dir>/
├── pr.md.j2
└── evidence/
    ├── queries/      *.json from BQ / DuckDB / SQL runs (bq --format=prettyjson dumps)
    ├── code/         optional cache; usually read live from working tree via code_expand
    ├── images/       optional; usually skip in favor of paste-to-GitHub
    └── perf/         *.json before/after shapes for delta_table comparisons (optional)
```

## Why this layout

| Subdir | Loaded via | Purpose |
|---|---|---|
| `queries/` | `load_json('queries/q_X.json')` | Tabular data — feeds `md_table` filter |
| `code/` | `load_text('code/X.py')` OR `code_expand` from source tree | Code blocks |
| `perf/` | `load_json('perf/before.json') \| delta_table(load_json('perf/after.json'))` | Before/after comparison tables |
| `images/` | Usually unused — see below | — |

## Images: don't template them

Convention: paste images directly into the GitHub PR body editor. GitHub auto-uploads to user-attachments and inserts `<img>` HTML. Don't try to template image refs — you can't predict the URL until upload time.

If you DO need templated images (e.g. asset URLs you control), use `snippets/before_after_img_table.j2`.

## CWD vs evidence dir vs root_path

Three distinct concepts:

| Concept | What | Resolution |
|---|---|---|
| `--evidence <dir>` | Where `load_json` / `load_text` resolve paths | Per-render flag |
| `frontmatter.root_path` | Where `code_expand` resolves paths | Per-template YAML |
| `process.cwd()` | Where npx is invoked from | Where snippet-include discovery walks up from |

Keep them distinct: evidence dir for synthetic / dumped artifacts; root_path for live source tree.
