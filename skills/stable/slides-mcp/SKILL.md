---
name: slides-mcp
description: Reference of code execution patterns from the google slides mcp server. Skip this skill if not using slides code executions `exec_batch_update` tool
---
# Composing exec_batch_update requests

A reference for using `exec_batch_update` to make legwork-shaped edits to Google Slides via slides-mcp. The agent writes Slides API Request dicts directly — this doc is the cheat sheet.

## Quick reference

### objectId discovery

Slides API edits target objectIds. Two shapes:

- **Slide objectIds** — call `get_deck_outline(deck_url)` → each slide has `slide_id` field. Used in `pageObjectId` (for create-on-slide) or `pageObjectIds` (for `replaceAllText` scoping).
- **Element objectIds** — call `read_slides(deck_url, slides=[sid], detail="raw")` → each element has `id` field. Used in element-level `update*`/`deleteObject` requests.

### EMU cheat sheet

Slides API uses **EMU** (English Metric Unit). 1 inch = 914400 EMU.

| Item | EMU |
|---|---|
| 16:9 deck width | 9144000 (10 in) |
| 16:9 deck height | 5143500 (5.625 in) |
| 1 inch | 914400 |
| 1 cm | 360000 |
| 1 pt | 12700 |

### Common Request kinds

| Kind | When | Destructive? |
|---|---|---|
| `createShape` | Add a TEXT_BOX, RECTANGLE, ELLIPSE, etc. | No |
| `createImage` | Add an image from URL | No |
| `insertText` | Add text into a shape (after `createShape`) | No |
| `updateShapeProperties` | Set fill/border/autofit | No |
| `updateTextStyle` | Set font, size, color, bold | No |
| `updatePageElementTransform` | Move/resize/rotate | No |
| `replaceAllText` | Find-and-replace across slide(s) | **Yes** |
| `deleteObject` | Remove a shape or slide | **Yes** |
| `deleteSlide` | Remove an entire slide | **Yes** |
| `createSlide` | Add a new slide | No |
| `duplicateObject` | Clone a shape or slide | No |

For every destructive kind, pass `confirm_destructive=True` to `exec_batch_update`.

### The autofit:NONE invariant

When you create a `TEXT_BOX` and call `insertText`, Google Slides auto-applies non-NONE autofit which causes subsequent `updateShapeProperties` calls to fail with an opaque error. **Always emit:**

```python
{
  "updateShapeProperties": {
    "objectId": "<your shape's id>",
    "shapeProperties": {"autofit": {"autofitType": "NONE"}},
    "fields": "autofit.autofitType"
  }
}
```

… AFTER `insertText` and BEFORE any other `updateShapeProperties`. Lesson from a server-side regression caught in 2026-04 — trust the rule, don't relitigate it.

## Worked examples

### Example 1 — Rename a deck title

```python
exec_batch_update(
    deck_url="https://docs.google.com/presentation/d/.../edit",
    requests=[{
        "replaceAllText": {
            "containsText": {"text": "Old Title", "matchCase": True},
            "replaceText": "New Title"
        }
    }],
    confirm_destructive=True,  # replaceAllText is destructive
    post_state="summary"
)
```

`replaceAllText` is deck-wide unless you pass `pageObjectIds: [<slide_id>, ...]` to scope it.

### Example 2 — Add a timestamp footer to every slide (manual; for section-aware footers use `add_section_footers`)

```python
# 1. Get slide IDs
outline = get_deck_outline(deck_url)
slide_ids = [s["slide_id"] for s in outline["slides"]]

# 2. Build request list
DECK_W = 9144000
DECK_H = 5143500
FOOTER_W = 3000000
FOOTER_H = 250000
MARGIN = 100000

requests = []
for sid in slide_ids:
    oid = f"my_timestamp_{sid[-8:]}"
    requests.append({
        "createShape": {
            "objectId": oid,
            "shapeType": "TEXT_BOX",
            "elementProperties": {
                "pageObjectId": sid,
                "size": {"width": {"magnitude": FOOTER_W, "unit": "EMU"},
                         "height": {"magnitude": FOOTER_H, "unit": "EMU"}},
                "transform": {"scaleX": 1, "scaleY": 1,
                              "translateX": DECK_W - FOOTER_W - MARGIN,
                              "translateY": DECK_H - FOOTER_H - MARGIN,
                              "unit": "EMU"}
            }
        }
    })
    requests.append({
        "insertText": {"objectId": oid, "text": "Last updated: 2026-05-07", "insertionIndex": 0}
    })
    requests.append({  # autofit:NONE invariant — see above
        "updateShapeProperties": {
            "objectId": oid,
            "shapeProperties": {"autofit": {"autofitType": "NONE"}},
            "fields": "autofit.autofitType"
        }
    })
    requests.append({
        "updateTextStyle": {
            "objectId": oid,
            "textRange": {"type": "ALL"},
            "style": {"fontSize": {"magnitude": 9, "unit": "PT"}},
            "fields": "fontSize"
        }
    })

# 3. Dry run first
preview = exec_batch_update(deck_url, requests, dry_run=True)
# inspect preview["request_kinds"], preview["destructive_kinds_detected"]

# 4. Fire
result = exec_batch_update(deck_url, requests, post_state="summary")
# result["post_state"]["deck_outline"]   = whole deck index
# result["post_state"]["slides"]         = each touched slide projected at "summary" detail
# result["affected_slide_ids"]           = ["g1", "g2", …]
```

### Example 3 — Change global font on all titles

```python
# 1. Discover title element IDs across the deck
outline = get_deck_outline(deck_url)
title_objectids = []
for s in outline["slides"]:
    detail = read_slides(deck_url, slides=[s["slide_id"]], detail="raw")
    for shape in detail["slides"][0].get("shapes", []):
        if shape.get("kind") == "text" and "title" in (shape.get("role") or "").lower():
            title_objectids.append(shape["id"])

# 2. Build batch
requests = [
    {"updateTextStyle": {
        "objectId": oid,
        "textRange": {"type": "ALL"},
        "style": {"fontFamily": "Inter"},
        "fields": "fontFamily"
    }}
    for oid in title_objectids
]

# 3. Fire
exec_batch_update(deck_url, requests, post_state="outline")
```

## Tips

- **Always `dry_run=True` first** for non-trivial batches. The preview surfaces `destructive_kinds_detected` so you can decide whether to pass `confirm_destructive=True`.
- **Pick the right `post_state`**: `"none"` for blind fire-and-forget, `"outline"` to confirm slide structure didn't break, `"summary"` (default) to read back text changes, `"full"` for debugging.
- **Footer positioning is approximate.** Pixel-precise placement requires visual feedback (Slides UI) — agents work blind here.

## Reference

- Slides API Request reference: <https://developers.google.com/slides/api/reference/rest/v1/presentations/request>
