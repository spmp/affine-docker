Feature 03: dotted line style (diff-first export)

Patch strategy:

- These patches are generated from the final net diff (`pr/02-color-palettes..pr/03-dotted-line-style`), grouped by scope.
- They intentionally avoid commit-by-commit history export.

Patch files:

- `0001-dotted-line-style-runtime-core.diff.patch`
  - dotted stroke rendering for note/shape/connector
  - edgeless line style panel includes dotted and none
  - line-width step set tightened for the panel

- `0002-dotted-line-style-settings-ui.diff.patch`
  - Editor settings parity for note/shape/connector border styles
  - includes connector `None` option wiring and ids

Excluded scope:

- tests (`tests/**`, `**/__tests__/**`, integration/e2e specs)
