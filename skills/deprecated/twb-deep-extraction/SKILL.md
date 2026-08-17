---
name: twb-deep-extraction
description: Autonomous TWB XML extraction. Extracts all semantic metadata from a Tableau .twb file using yq -- datasources, SQL, worksheets, dashboards, calculated fields, parameters, field-to-sheet mapping, dead code scan, and RLS audit. Optimized for subagent spawning -- self-contained, no conversation needed. Use when you need to extract metadata from a TWB file before migration.
argument-hint: "[twb-file-path]"
---

# TWB Deep Extraction (Subagent-Optimized)

> **For subagent spawning.** Copy the relevant sections into your subagent prompt along with the TWB path. The subagent runs autonomously and returns structured tables. Read `rules/*.md` for detailed yq patterns and analysis procedures.

## Tool Setup

All queries use `query_yq` with `input_format: "xml"` on the TWB file.

---

## Workflow Guides

Read these before starting:

- [rules/extraction-steps.md](rules/extraction-steps.md) -- E1 through E10: all yq patterns for datasources, SQL, worksheets, dashboards, calcs, parameters, field mapping, measure names, viz marks, and tile filters
- [rules/analysis.md](rules/analysis.md) -- RLS audit, field ID resolution, shared view filters, dashboard actions, dead code detection, scope pruning

---

## Output Format

Return structured markdown tables for each E-step:

```
## E1 Results: Datasource Inventory
| # | Name | Caption | Inline | SQL Type |

## E2 Results: SQL Extraction
| DS | SQL Structure | Key BQ Tables | Full SQL text |

## E3 Results: Worksheets
| # | Sheet | Datasource(s) |

## E4 Results: Dashboards
| Dashboard | Sheets Contained | Zone Count |

## E5 Results: Calculated Fields
| # | Caption | Datasource | Datatype | Formula |

## E6 Results: Parameters
| # | Caption | Type | Domain | Default | Allowed Values |

## E7 Results: Field-to-Sheet
| Field | Sheets Using It |

## E8 Results: Dead Code
| Calc | Status (active/indirect/dead) | Reason |

## RLS Audit
| Datasource | Has RLS? |

## Shared View Filters
| Datasource | Filter | Value |

## V2 vs V1 Diff (if v1_findings provided)
| Aspect | V1 | V2 | Delta |
```

---

## Common Pitfalls

| Pitfall | Fix |
|---------|-----|
| FCP path returns null | Try both `false...relation` (single) and `true...relation` (collection) |
| Missing `+content` for SQL text | SQL is in CDATA `+content`, not attributes |
| yq garbled output | Always `input_format: "xml"` |
| Dots in datasource IDs | Wrap in quotes: `select(.+@name == "federated.xxx")` |
| Collection DS treated as single SQL | Check `+@type == "collection"` first |
| Filter target location | Actions: target in `command.param`, not `+@target` |
| order_channel exclusions vary per sheet | Check each sheet's filter settings individually |
| Hardcoded dates in filters | These are Tableau snapshots, not requirements |
