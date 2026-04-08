Feature 03: color palettes (diff-first export)

Patch strategy:

- These patches are generated from the final net diff (`upstream/canary..pr/03-color-palettes`), grouped by scope.
- They are intentionally NOT commit-by-commit exports.

Patch files:

- `0001-color-palettes-runtime-core.diff.patch`
  - runtime behavior for shape/pen/connector palettes
  - gradient-capable shape picker wiring
  - shape palette model/theme centralization and memory behavior
  - includes lockfile changes required by runtime package updates

- `0002-color-palettes-settings-ui.diff.patch`
  - settings appearance palette UI and persistence wiring
  - kept separate for conflict isolation in docker layering

- `0003-edgeless-menu-width.diff.patch`
  - edgeless toolbar menu width tweak only
  - isolated so other features can reuse/override independently

Excluded scope:

- tests (`tests/**`, `**/__tests__/**`, integration/e2e specs)
