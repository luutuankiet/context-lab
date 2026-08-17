# Extraction Steps (E1-E10)

## E1: Datasource Inventory

```yaml
# All datasources -- names, captions, inline status
.workbook.datasources.datasource[] | {name: .+@name, caption: .+@caption, inline: .+@inline}
```

## E2: SQL Extraction

### Standard path (published datasources)
```yaml
.workbook.datasources.datasource[].connection.relation
```

### FCP path (inline datasources -- `inline=true`)
```yaml
# Single-relation
.workbook.datasources.datasource[].connection."+_.fcp.ObjectModelEncapsulateLegacy.false...relation"
# Collection/join (Tableau Relationships)
.workbook.datasources.datasource[].connection."+_.fcp.ObjectModelEncapsulateLegacy.true...relation"
```

**Always check both paths.** A workbook can mix standard and inline datasources.

### Collection datasources (multi-SQL joined)
If FCP `true...relation` has `+@type == "collection"`, it contains multiple joined SQL blocks:
```yaml
# Get relation objects within collection
.workbook.datasources.datasource[] | select(.+@caption == "DS_NAME") | .connection."+_.fcp.ObjectModelEncapsulateLegacy.true...relation" | .relation[]
# Get join keys from object-graph
.workbook.datasources.datasource[] | select(.+@caption == "DS_NAME") | .connection."+_.fcp.ObjectModelEncapsulateLegacy.true...object-graph" | .relationships.relationship[]
```

### BQ connection details
```yaml
.workbook.datasources.datasource[].connection.named-connections.named-connection.connection
# Attributes: +@CATALOG (project), +@schema (dataset), +@class (bigquery)
```

## E3: Worksheet Inventory
```yaml
.workbook.worksheets.worksheet[] | .+@name
```

### Worksheet -> Datasource dependency
```yaml
.workbook.worksheets.worksheet[].table.view.datasource-dependencies
```

## E4: Dashboard Inventory + Zones
```yaml
# Dashboard names
.workbook.dashboards.dashboard[] | .+@name
# Zones for specific dashboard (layout, positions, filter configs)
.workbook.dashboards.dashboard[] | select(.+@name == "DASHBOARD_NAME") | .zones.zone[]
# Dashboard size
.workbook.dashboards.dashboard[] | select(.+@name == "DASHBOARD_NAME") | .size
```

### Zone Types in Dashboard Layout

Dashboard zones have a `+@type-v2` attribute indicating their role:

| Zone Type | What It Is | Migration Relevance |
|-----------|-----------|--------------------||
| *(no type -- has `+@name`)* | Worksheet tile | The actual chart/table -> becomes a dashboard element |
| `paramctrl` | Parameter control | Slider, dropdown, date picker -> becomes a dashboard filter |
| `filter` | Quick filter | Dimension filter on sidebar -> becomes a dashboard filter |
| `color` | Color legend | Color encoding scale -> informs `vis_config` or conditional formatting |
| `layout-flow` | Container | Groups zones (horz/vert) -> informs Looker grid layout |
| `layout-basic` | Container | Basic layout wrapper -> informs row/col placement |

**Why this matters:** `paramctrl` zones tell you which parameters each dashboard exposes (maps to dashboard-level filters). `filter` zones tell you which dimension quick-filters exist. Zones without a type but with `+@name` are the actual worksheet tiles.

## E5: Calculated Fields
```yaml
.workbook.datasources.datasource[].column[] | select(has("calculation")) | {name: .+@name, caption: .+@caption, formula: .calculation.+@formula, datatype: .+@datatype}
```

## E6: Parameters
```yaml
.workbook.datasources.datasource[] | select(.+@name == "Parameters")
# Per parameter: +@caption, +@datatype, +@value, +@param-domain-type, .members.member[]
```

## E7: Field-to-Sheet Mapping
```yaml
# Which columns each worksheet references
.workbook.worksheets.worksheet[].table.view.datasource-dependencies.datasource-dependency.column-instance[] | .+@column
```

## E8: Measure Names Investigation
For sheets with Measure Names on axis:
```yaml
.workbook.worksheets.worksheet[] | select(.+@name == "SHEET_NAME") | .table.view.filter[] | select(.+@column == ":Measure Names")
```
Extract the `groupfilter.function` members to find which measures are included.

---

## E9: Visualization Mark Type

Determines which Looker chart type to use for each dashboard tile.

```yaml
# Mark type for a specific worksheet
.workbook.worksheets.worksheet[] | select(.+@name == "SHEET_NAME") | .table.view.mark

# Batch: mark class for ALL worksheets
.workbook.worksheets.worksheet[] | .+@name + " | " + .table.view.mark.+@class
```

**Tableau Mark -> Looker Viz Type:**

| Tableau Mark | Looker Type | Notes |
|-------------|-------------|-------|
| Square | `looker_grid` | Heatmap. Add `enable_conditional_formatting: true` |
| Line | `looker_line` | Standard line chart |
| Bar | `looker_column` | Vertical bars. `looker_bar` for horizontal |
| Circle | `looker_scatter` | Scatter/bubble chart |
| Text | `looker_grid` | Text table (default grid) |
| Automatic | Context-dependent | Tableau auto-selects -- verify what it resolved to |
| Gantt Bar | `looker_grid` | No native Gantt in Looker -- use table with date ranges |

> **Always verify mark type before choosing Looker viz.** Don't assume line chart -- many Tableau sheets use Square marks (heatmaps) that render as colored grids, not line charts.

## E10: Worksheet-Level Filters (Tile Filter Config)

Reveals which filters should be hardcoded on dashboard tiles vs exposed as user controls.

```yaml
# All filters on a specific worksheet
.workbook.worksheets.worksheet[] | select(.+@name == "SHEET_NAME") | .table.view.filter[]

# Key attributes per filter:
#   +@column          -> field being filtered
#   +@included-values -> "in" (include list) or "out" (exclude list)
#   .groupfilter      -> filter values/conditions
```

**Decision rule for dashboard design:**
- Filter has the **same value on ALL sheets** of a dashboard -> **hardcode as tile filter** (e.g., `between_dates: "Yes"`)
- Filter **varies between sheets** or is user-selectable -> **expose as dashboard filter** (e.g., `country`)
- Filter exclusion **differs between sheets** -> **flag for user review** (e.g., order_channel excludes `internal` on most sheets but `wholesale` on one)
