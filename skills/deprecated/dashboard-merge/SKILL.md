---
name: dashboard-merge
description: Merge multiple individual Looker LookML dashboards into a single tabbed dashboard. Use when the user provides individual .dashboard.lookml files and asks to combine/merge/unify them into one tabbed dashboard. Also use when the user says "merge these dashboards" or provides new individual dashboards to add to an existing tabbed dashboard.
user-invocable: true
---

# Dashboard Merge Skill

Merge N individual Looker dashboards into **one tabbed dashboard** with deduplicated filters.

## When to Use

- User provides multiple `.dashboard.lookml` files and asks to merge/combine/unify
- User provides new individual dashboards to add as tabs to an existing merged dashboard
- User says "merge these dashboards" or "add this to the tabbed dashboard"

## Algorithm

### Step 1: Inventory Filters

For each input dashboard, extract every filter and catalog:

| Field | What to Record |
|-------|----------------|
| `name` | Original filter name |
| `title` | Display title |
| `field` | LookML field reference |
| `model` / `explore` | For UI suggestions |
| `default_value` | Starting value |
| `ui_config` | Widget type |
| Which tiles `listen:` to it | The actual field mapping per tile |

### Step 2: Deduplicate Filters

**Merge criteria — two filters are the same if:**
1. They represent the same **concept** (e.g., "Region", "Date Range", "Date Segment")
2. They have compatible `default_value` (ideally identical; use majority-wins if not)
3. Tiles can map the shared filter to their own explore-specific field via `listen:`

**Key insight:** The filter definition's `model`/`explore`/`field` only controls the **UI suggestion list**. Each tile independently maps the filter to its own field via the `listen:` block. So one global `region` filter defined on `orders.region_param` can serve tiles from `online_orders` that listen to `online_orders.region_param`.

**Naming convention for merged filters:**
- Use clean, canonical names: `report_range`, `region`, `date_segment`, `customer_type`
- Use `name` field with lowercase_snake_case for shared/common filters
- Use Title Case `name` for tab-specific filters: `Tag Name`, `Store Name`, `Show Top N`
- **NO bracket prefixes** like `[Tab Name]` — keep titles clean
- All filters are **global** (no `tab:` property) — they appear on every tab
- Tiles that don't need a filter simply don't include it in their `listen:` block

### Step 3: Build Tabs

**Tab conventions:**
- `name` and `label` use **Title Case**: `name: Online Overview`, `label: Online Overview`
- `tab_name` on each element matches the tab `name` exactly
- Order tabs by domain grouping (e.g., Overview → Online tabs → Retail tabs)
- Row numbers reset per tab (each tab starts at `row: 0`)

### Step 4: Remap Element `listen:` Blocks

For each tile element:
1. Read the original `listen:` mapping: `original_filter_name: field_on_tile`
2. Find which merged filter replaces `original_filter_name`
3. Write: `merged_filter_name: field_on_tile` (the field stays the same!)

**Example:**
```yaml
# Original (online_orders_overview dashboard)
listen:
  date_range: online_orders.created_at_date
  region: online_orders.region_param

# Merged (filter names changed, fields unchanged)
listen:
  report_range: online_orders.created_at_date
  region: online_orders.region_param
```

### Step 5: Element Name Uniqueness

- Element `name` must be unique across the entire dashboard
- **Convention:** Use the original tile `title` as the `name` verbatim
- If two tiles from different dashboards share the same title, disambiguate:
  - Prefix with context: `"Order Volume (New vs Returned)"` vs `"Order Volume (New orders vs Returned orders)"`
  - Or append tab context to the `name` only (keep `title` as-is)

## Output Format

```yaml
---
- dashboard: {dashboard_id}
  title: {Dashboard Title}
  preferred_viewer: dashboards-next
  description: '{description}'
  preferred_slug: {slug if provided}
  theme_name: ''
  layout: newspaper

  tabs:
  - name: {Tab Title Case}
    label: {Tab Title Case}
  # ... more tabs

  elements:

  # ═══════════════════════════════════════════════════════════
  # TAB: {Tab Name}
  # ═══════════════════════════════════════════════════════════

  - title: {Tile Title}
    name: {Tile Title}   # matches title verbatim
    model: ...
    explore: ...
    type: ...
    # ... full vis config preserved from original
    listen:
      {merged_filter_name}: {original_field_mapping}
    row: N
    col: N
    width: N
    height: N
    tab_name: {Tab Name}   # matches tab name exactly

  # ... more elements

  filters:

  # ── Shared ──
  - name: report_range
    title: Report Range
    type: field_filter
    # ...

  # ── Domain-specific ──
  - name: Tag Name
    title: Tag Name
    type: field_filter
    # ...
```

## Conventions (from reviewed reference)

1. **All filters global** — no `tab:` property. Filters show on every tab.
2. **Tiles preserve full vis config** — copy all visualization properties from originals.
3. **Tab separator comments** use `═══` box-drawing characters.
4. **Hardcoded tile filters preserved** — if a tile had `filters: { field: value }`, keep it.
5. **`defaults_version: 1`** on every element.
6. **Filter order in the `filters:` block:** shared/common first, then domain-specific.
7. **For `default_value` conflicts:** use the value from the majority of source dashboards. Note: merging means some tabs lose their original default — this is an expected tradeoff.
8. **single_value tiles** should include: `custom_color_enabled`, `show_single_value_title`, `show_comparison`, `comparison_type`, `comparison_reverse_colors`, `show_comparison_label`, `smart_single_value_size`.

## Incremental Merge (Adding to Existing)

When user provides new dashboards to add to an already-merged tabbed dashboard:

1. Read the existing merged dashboard
2. Inventory its current filters and tabs
3. For each new dashboard:
   a. Check if its filters match existing ones → reuse
   b. If new filter needed → add to the `filters:` block
   c. Add new tab to `tabs:` list
   d. Add elements with `tab_name` pointing to new tab
   e. Remap `listen:` to use existing + new filter names
4. Output the full updated dashboard

## Checklist Before Output

- [ ] All element `name` values are unique across entire dashboard
- [ ] All `tab_name` values on elements match a tab's `name` exactly
- [ ] All `listen:` filter references match a filter's `name` in the `filters:` block
- [ ] Filters block declared exactly ONCE
- [ ] Each filter `name` is unique
- [ ] No `tab:` property on any filter
- [ ] Full vis config preserved from originals (not stripped)
- [ ] Row numbers reset per tab
