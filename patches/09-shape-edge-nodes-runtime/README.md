# Shape Edge-Nodes Runtime (Seed)

This directory contains a seed patch for the shapes/edge-nodes feature.

Current status:

- `0001-...patch.disabled` is intentionally disabled so it is NOT applied by default in connector-only builds.
- To activate it for shapes work, rename the file extension back to `.patch`.

Why:

- Connector runtime (`05-connector-runtime`) now keeps baseline anchor density.
- Expanded per-shape anchor density is tracked here for the shapes feature.
