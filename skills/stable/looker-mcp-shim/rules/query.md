# Query — Running Tile & Explore Queries

## run_tile

Executes a tile's query WITH dashboard filters auto-applied.

**By element ID:**
```
run_tile({element_id: "5678"})
run_tile({element_id: "5678", format: "sql"})
run_tile({element_id: "5678", format: "json", limit: 5})
```

**By ordinal (from inspect output):**
```
run_tile({dashboard_id: "1234", tile: "#2"})
```

**By title match:**
```
run_tile({dashboard_id: "1234", tile: "Revenue"})
```

**Override a filter:**
```
run_tile({element_id: "5678", filters: {"customers.segment": "Enterprise"}})
```

**Compare dev vs prod:**
```
run_tile({element_id: "5678", force_production: true})
```

## Filter Auto-Wiring

`run_tile` automatically:
1. Reads the tile's `filter_wiring` (which dashboard filters map to which query fields)
2. Reads the dashboard's filter default values
3. Applies them to the query before executing

This is why `run_tile({element_id: "5678"})` returns data, while a raw SDK `run_query` on the same query_id returns `[]` — the tile's query depends on parameter values set by dashboard filters.

You can override any auto-wired filter by passing it in `filters`.

## run_query (ad-hoc)

```
run_query({
  model: "acme",
  explore: "orders",
  fields: ["customers.segment", "orders.total_revenue"],
  filters: {"orders.created_date": "30 days"},
  sorts: ["orders.total_revenue desc"],
  limit: 10
})
```

## Long-Running Queries

Both tools handle BigQuery timeouts automatically:
- Default timeout: 120 seconds (configurable via `timeout` param)
- On timeout, falls back to async query task (same as Looker UI)
- Polls for completion, returns results when ready

## Output Formats

| Format | Returns |
|--------|--------|
| `json` (default) | Array of row objects |
| `sql` | Compiled SQL string (wrapped in `{sql, element_id}`) |
| `csv` | CSV string |
