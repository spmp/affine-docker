# Connector Runtime Scope

This patch set is the curated connector runtime core.

Included scope:

- connector model + consts
- connector manager/watcher/path/jump rendering
- connector toolbar/menu/actions
- connector waypoint actions in edgeless more menu

Excluded from runtime scope on purpose:

- shape package/workspace/lockfile churn
- test helper changes

Related patch layers:

- `06-connector-support-uncertain/` (suspected dependency files)
- `07-connector-tests/` (test helper and spec adjustments)
