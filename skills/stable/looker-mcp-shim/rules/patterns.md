# Patterns — Common Recipes

## Migration QA (Tableau → Looker)

```
1. inspect({target: "1234"})  → list all tiles
2. For each tile:
   a. run_tile({dashboard_id: "1234", tile: "#N"})  → get data
   b. Compare against Tableau values
   c. If mismatch:
      - run_tile({dashboard_id: "1234", tile: "#N", format: "sql"})  → check SQL
      - Fix LookML, git push, reset_to_remote, validate
      - Re-run tile to verify
```

## Clone a Dashboard Tile

```
1. inspect({target: "tile:5678"})  → get fields, query, vis_config
2. create_tile({
     dashboard_id: "1234",
     title: "Revenue (Copy)",
     query: {model, view, fields, sorts, limit, vis_config}  → paste from inspect
   })
```

## Bulk Update Tile Vis Config

```
1. inspect({target: "1234"})  → get all tile IDs
2. For each tile:
   update_tile({element_id: tile.id, query: {vis_config: {show_view_names: false}}})
```

## Add Filter Wired to All Tiles

```
1. create_filter({dashboard_id: "1234", name: "region", title: "Region", type: "field_filter", ...})
2. For each tile (via execute_sdk_code):
   - Read tile's listen array
   - Append {dashboard_filter_name: "region", field: "view.region_field"}
   - Update element
```

## LookML Dashboard → UDD → Iterate → Export

```
1. inspect({target: "model::dashboard_name"})  → check source
2. import_lookml_dashboard({lookml_dashboard_id: "model::dashboard_name"})
   → {status: "success", imported_dashboard: {id: "4321"}}
3. [iterate on UDD 4321 with mutation tools]
4. export_dashboard_lookml({dashboard_id: "4321"})
   → {lookml: "---\n- dashboard: ...\n  ..."}
5. Write lookml to .dashboard.lookml file
6. git push, reset_to_remote, validate
```

## Dev vs Prod Data Comparison

```
const dev = await run_tile({element_id: "5678"})
const prod = await run_tile({element_id: "5678", force_production: true})
// Compare dev vs prod row by row
```

## Render Tile as PNG (via SDK escape hatch)

```
retrieve_sdk_methods({query: "render task element"})
describe_sdk_method({method: "create_dashboard_element_render_task"})
execute_sdk_code({code: `
  const task = await sdk.ok(
    sdk.create_dashboard_element_render_task('5678', 'png', 800, 600)
  )
  // Poll for completion
  let result
  while (true) {
    result = await sdk.ok(sdk.render_task(task.id, ''))
    if (result.status === 'success') break
    await new Promise(r => setTimeout(r, 1000))
  }
  const png = await sdk.ok(sdk.render_task_results(task.id))
  return {status: 'rendered', task_id: task.id, size: png.length}
`})
```
