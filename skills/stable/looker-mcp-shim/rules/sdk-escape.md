# SDK Escape Hatch — Method Discovery + Code Execution

For anything not covered by the dedicated tools, discover and execute any of Looker's 469 API methods.

## Workflow: Search → Describe → Execute

**Step 1: Find the method**
```
retrieve_sdk_methods({query: "schedule plan"})
retrieve_sdk_methods({query: "render png"})
retrieve_sdk_methods({tag: "Dashboard"})
```

Returns compact list: method name, summary, tags, HTTP endpoint.

**Step 2: Get full details**
```
describe_sdk_method({method: "scheduled_plans_for_dashboard"})
```

Returns: parameters with types, description, and a ready-to-paste code example.

**Step 3: Execute**
```
execute_sdk_code({code: `
  const plans = await sdk.ok(
    sdk.scheduled_plans_for_dashboard({dashboard_id: '1234', all_users: true})
  )
  return plans.map(p => ({name: p.name, cron: p.crontab}))
`})
```

## Available in Scope

| Variable | Type | Description |
|----------|------|------------|
| `sdk` | Looker40SDK | Authenticated, safety-proxied |
| `projectId` | string | Current LookML project ID |
| `currentMode` | "dev" \| "prod" | Current session mode |

## Pattern

```javascript
const result = await sdk.ok(sdk.METHOD_NAME(args))
return result  // must be JSON-serializable
```

## Common Tags for retrieve_sdk_methods

`Dashboard`, `Query`, `Look`, `Folder`, `LookmlModel`, `Project`, `Theme`, `RenderTask`, `ScheduledPlan`, `Content`, `Connection`, `Explore`

## Blocked Methods

These throw immediately: `deploy_ref_to_production`, `deploy_to_production`, `login_user`, `delete_group`, `delete_dashboard`, `delete_look`, `delete_folder`, and other destructive admin operations.

## Catalog Source

The method catalog is loaded from the Looker instance's own `swagger.json` at startup. It's always accurate for your specific Looker version.
