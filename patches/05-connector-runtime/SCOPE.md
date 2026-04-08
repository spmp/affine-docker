# Connector Runtime Scope (diff-first export)

Patch strategy:

- These patches are generated from the final net diff on connector branches, grouped by runtime vs settings scope.
- They intentionally avoid commit-history `format-patch` exports.

Patch files:

- `0001-connector-runtime-core.diff.patch`
  - connector model and runtime rendering/path updates
  - connector toolbar/menu/actions including waypoint actions
  - removes the `Jump` selector from connector slide menu content
  - adds full connector endpoint marker set support in model and renderers

- `0002-connector-settings-ui.diff.patch`
  - Editor settings updates for connector shape parity and corner radius
  - start/end endpoint dropdowns show full marker list with icons and scrolling
  - connector schema defaults/validation wiring required by settings

Excluded scope:

- tests (`tests/**`, `**/__tests__/**`, integration/e2e specs)
- unrelated workspace/package churn
