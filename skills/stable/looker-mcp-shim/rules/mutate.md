# Mutate — Creating, Updating, Deleting Tiles & Filters

## Create Tile

Provide an inline query (model + view + fields) or a saved query_id:

```
create_tile({
  dashboard_id: "1234",
  title: "Revenue by Region",
  query: {
    model: "acme",
    view: "orders",
    fields: ["orders.region", "orders.total_revenue"],
    sorts: ["orders.total_revenue desc"],
    limit: "20",
    vis_config: {type: "looker_bar"}
  }
})
```

The shim handles the two-step dance automatically (Looker API rejects inline queries on element create — it creates the query first, then references via query_id).

## Update Tile (Partial Merge)

Only send what changed. Existing fields, sorts, filters are preserved.

**Change title:**
```
update_tile({element_id: "5679", title: "New Title"})
```

**Change chart type (fields preserved):**
```
update_tile({element_id: "5679", query: {vis_config: {type: "looker_pie"}}})
```

**Change sort order:**
```
update_tile({element_id: "5679", query: {sorts: ["orders.total_revenue desc"]}})
```

**Add a filter to the query:**
```
update_tile({element_id: "5679", query: {filters: {"orders.region": "North"}}})
```

## Delete Tile

```
delete_tile({element_id: "5679"})
```

## Create Filter

```
create_filter({
  dashboard_id: "1234",
  name: "region_filter",
  title: "Region",
  type: "field_filter",
  dimension: "orders.region",
  model: "acme",
  explore: "orders",
  default_value: "North"
})
```

**UI types:** Set `ui_config` to control how the filter renders:
- `{type: "button_toggles", display: "inline"}` — radio buttons
- `{type: "dropdown_menu"}` — dropdown
- `{type: "tag_list"}` — multi-select tags
- `{type: "advanced"}` — text input with operators

## Update Filter

```
update_filter({filter_id: "9012", title: "Updated", default_value: "South"})
update_filter({filter_id: "9012", ui_config: {type: "button_toggles"}})
```

## Delete Filter

```
delete_filter({filter_id: "9012"})
```

## Wiring a Filter to a Specific Tile

Dashboard filters connect to tiles via `filter_wiring`. To wire a filter to ONLY one tile, use `execute_sdk_code`:

```
execute_sdk_code({code: `
  const el = await sdk.ok(sdk.dashboard_element('5678', ''))
  const listens = el.result_maker?.filterables?.[0]?.listen || []
  listens.push({
    dashboard_filter_name: 'my_filter',
    field: 'customers.segment'
  })
  await sdk.ok(sdk.update_dashboard_element('5678', {
    result_maker: { filterables: [{ listen: listens }] }
  }))
  return {wired: true, total_listens: listens.length}
`})
```

This adds the wiring to that tile only — other tiles are not affected.

---

## vis_config Reference

`vis_config` is an opaque JSON blob — the Looker API has **no schema** for it.
Types matter: wrong types crash Looker's frontend (e.g. `hidden_series: {}` → `e.map is not a function`).

### Before setting vis_config properties

1. **Inspect a working tile** that uses the property you want: `inspect({target: "tile:XXXX"})`
2. Copy the exact format from the response
3. Apply to your tile

Never guess types. Inspect first.

### Common Properties by Chart Type

#### All chart types

| Property | Type | Values | UI Tab |
|----------|------|--------|--------|
| `type` | string | `"looker_column"`, `"looker_bar"`, `"looker_line"`, `"looker_pie"`, `"looker_grid"`, `"looker_scatter"`, `"looker_area"` | Viz selector |
| `show_value_labels` | bool | `true` / `false` | Values |
| `show_view_names` | bool | `true` / `false` | — |
| `defaults_version` | number | `1` | — |

#### Bar / Column / Line / Area (`looker_column`, `looker_bar`, `looker_line`, `looker_area`)

| Property | Type | Values | UI Tab |
|----------|------|--------|--------|
| `stacking` | string | `""` (Grouped), `"normal"` (Stacked), `"percent"` (Stacked %) | Plot > Series Positioning |
| `hidden_fields` | string[] | `["view.field_name"]` — hides from viz entirely | — |
| `hidden_series` | **string[]** | `["series_name"]` — hides series from chart | Series |
| `series_types` | {string: string} | `{"view.field": "line"}` — override chart type per series | Series |
| `series_colors` | {string: string} | `{"view.field": "#FF0000"}` — color per series | Series |
| `series_labels` | {string: string} | `{"view.field": "Display Label"}` — rename series | Series |
| `show_legend` | bool | `true` / `false` | Plot > Legend |
| `legend_position` | string | `"center"`, `"left"`, `"right"` | Plot > Legend |
| `label_density` | number | `25` (default) | Values |
| `x_axis_gridlines` | bool | `true` / `false` | X |
| `y_axis_gridlines` | bool | `true` / `false` | Y |
| `show_x_axis_label` | bool | `true` / `false` | X |
| `show_x_axis_ticks` | bool | `true` / `false` | X |
| `show_y_axis_labels` | bool | `true` / `false` | Y |
| `show_y_axis_ticks` | bool | `true` / `false` | Y |
| `y_axis_scale_mode` | string | `"linear"`, `"log"` | Y |
| `y_axis_combined` | bool | `true` / `false` | Y |
| `x_axis_scale` | string | `"auto"`, `"ordinal"` | X |
| `x_axis_reversed` | bool | `true` / `false` | X |
| `y_axis_reversed` | bool | `true` / `false` | Y |
| `show_null_labels` | bool | `true` / `false` | Values |
| `show_totals_labels` | bool | `true` / `false` | Values |
| `limit_displayed_rows` | bool | `true` / `false` | Plot > Data |
| `trellis` | string | `""` (none), `"row"`, `"column"` | Plot |
| `point_style` | string | `"none"`, `"circle"`, `"square"` | Plot |
| `x_axis_zoom` | bool | `true` / `false` | X |
| `y_axis_zoom` | bool | `true` / `false` | Y |

#### Pie / Donut (`looker_pie`)

| Property | Type | Values | UI Tab |
|----------|------|--------|--------|
| `value_labels` | string | `"legend"`, `"labels"`, `"none"` | Plot |
| `label_type` | string | `"labVal"`, `"labPer"` | Plot |
| `inner_radius` | number | `0` (pie) to `80` (donut) | Plot |

#### Grid / Table (`looker_grid`)

| Property | Type | Values | UI Tab |
|----------|------|--------|--------|
| `show_row_numbers` | bool | `true` / `false` | Plot |
| `transpose` | bool | `true` / `false` | Plot |
| `truncate_text` | bool | `true` / `false` | Plot |
| `hide_totals` | bool | `true` / `false` | Plot |
| `hide_row_totals` | bool | `true` / `false` | Plot |
| `size_to_fit` | bool | `true` / `false` | Plot |
| `table_theme` | string | `"white"`, `"gray"`, `"transparent"`, `"unstyled"` | Plot |
| `header_text_alignment` | string | `"left"`, `"center"`, `"right"` | Plot |
| `header_font_size` | number | `12` (default) | Plot |
| `rows_font_size` | number | `12` (default) | Plot |
| `minimum_column_width` | number | `75` (default) | Plot |
| `column_order` | string[] | `["field_name", ...]` — column display order | Plot |
| `show_totals` | bool | `true` / `false` | Plot |
| `show_row_totals` | bool | `true` / `false` | Plot |

#### Table Calculations (all chart types)

| Property | Type | Notes |
|----------|------|-------|
| `table_calculations` | object[] | `[{label: "Name", expression: "${view.field} / sum(${view.field})", value_format: "0.0%"}]` |

### Dangerous Properties (type mismatches that crash)

| Property | Correct Type | Wrong Type That Crashes | Error |
|----------|-------------|------------------------|-------|
| `hidden_series` | `string[]` (array) | `{}` or `{field: true}` (object) | `e.map is not a function` |
| `hidden_fields` | `string[]` (array) | `{}` (object) | Frontend crash |
| `series_types` | `{string: string}` (object) | `[]` (array) | Unexpected behavior |
| `table_calculations` | `object[]` (array) | `{}` (object) | Frontend crash |
