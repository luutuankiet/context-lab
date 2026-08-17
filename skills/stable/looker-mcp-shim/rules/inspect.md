# Inspect — Dashboard & Tile Inspection

## Dashboard Level

```
inspect({target: "1234"})
inspect({target: "https://host/dashboards/1234"})
```

Returns: tile index with `#` ordinals, IDs, titles, types, field counts, query IDs. Plus all dashboard filters with default values.

Use ordinals to reference tiles naturally: `#1`, `#2`, etc.

## Tile Level

```
inspect({target: "tile:5678"})
```

Returns: fields, filters, sorts, vis_config, filter_wiring (which dashboard filters connect to which fields), query_id.

## URL-Smart Input

| Input | Resolves To |
|-------|------------|
| `"1234"` | Dashboard 1234 |
| `"tile:5678"` | Tile detail |
| `"https://host/dashboards/1234"` | Dashboard 1234 |
| `"https://host/explore/acme/orders?fields=..."` | Explore |
| `"acme::orders_overview"` | LookML Dashboard |

## Reading Filter Wiring

The `filter_wiring` array shows how dashboard filters connect to tile fields:

```json
{"listen": [
  {"dashboard_filter_name": "group_by", "field": "orders.orders_group_by_revenue_param"},
  {"dashboard_filter_name": "date_range", "field": "orders.orders_date_range"}
]}
```

This means: when the dashboard filter "group_by" changes, it sets the field `orders.orders_group_by_revenue_param` on this tile's query. `run_tile` uses this to auto-apply filters.

## LookML Dashboard Inspection

LookML dashboards use `model::dashboard_name` format:

```
inspect({target: "acme::orders_overview"})
inspect({target: "https://host/dashboards/acme::my_dashboard"})
```

Response includes a `hint` field steering you to `import_lookml_dashboard` for iteration.
LookML dashboard tiles cannot be mutated directly — they are code-defined.

To iterate: use `import_lookml_dashboard` to create a UDD copy, mutate the UDD,
then `export_dashboard_lookml` to get the LookML YAML back.
