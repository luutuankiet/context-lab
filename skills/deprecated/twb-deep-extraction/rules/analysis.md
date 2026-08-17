# Analysis: RLS, Field Resolution, Filters, Actions, Dead Code

## RLS Audit (SECURITY -- NON-NEGOTIABLE)

Run for EVERY workbook before migration:
```yaml
.workbook.datasources.datasource[] | .+@caption + " | user-filter=" + (.+@user-filter // "null")
```
If any result is NOT null -> **STOP.** Report: `🔴 RLS detected on <datasource>. Do not migrate without security team sign-off.`

---

## Field ID Resolution (3 Patterns)

When encountering obfuscated field IDs in filters/encodings:

| Pattern | Example | Resolution |
|---------|---------|------------|
| `none:FIELD:nk` | `[none:REGION:nk]` | Strip prefix/suffix -> `REGION` |
| `none:Calculation_NNNN:nk` | `[none:Calculation_123...:nk]` | Look up: `.column[] \| select(.+@name == "[Calculation_NNNN]") \| .+@caption` |
| `usr:CAPTION_NNNN:qk` | `[usr:# Orders..._456...:qk]` | Strip `usr:` and `_NNNN:qk` suffix -> caption embedded |

---

## Shared View Filters (sql_always_where source)
```yaml
# Workbook-level filters applied to all sheets using a datasource
.workbook.datasources.datasource[]."_.fcp.ObjectModelEncapsulateLegacy.false...object-graph"
# Also check:
.workbook."shared-views"
```

## Dashboard Actions
```yaml
.workbook.actions.action[]
# Key: target is in command.param[+@name=="target"].+@value, NOT +@target on action
```

---

## Dead Code Detection

1. Build set: ALL calc names per datasource (E5)
2. Build set: ALL column refs per worksheet (E7)
3. Calcs in NO worksheet = **dead candidates**
4. Check indirect: dead calc feeds a live calc -> **keep as hidden component**
5. Report: active / indirect-only / truly dead

## Scope Pruning

1. Map dashboards -> worksheets (E4 zones)
2. Worksheets NOT on any dashboard = **orphan candidates**
3. Report: dashboard-visible vs orphan sheets
