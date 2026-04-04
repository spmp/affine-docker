# Connector Support (Uncertain) Files

These files were separated from runtime core because scope is uncertain:

- `blocksuite/affine/gfx/shape/package.json`
- `blocksuite/affine/gfx/shape/src/toolbar/shape-menu-config.ts`
- `blocksuite/affine/model/src/consts/index.ts`
- `tools/utils/src/workspace.gen.ts`
- `yarn.lock`

Current hypothesis (feature ownership):

- `blocksuite/affine/gfx/shape/package.json` -> likely "connection-point hover / edge-node hover" feature
- `tools/utils/src/workspace.gen.ts` -> wiring for `connection-point-hover` widget package
- `yarn.lock` -> dependency lock update tied to above wiring
- `blocksuite/affine/model/src/consts/index.ts` -> likely accidental duplicate export (not required)
- `blocksuite/affine/gfx/shape/src/toolbar/shape-menu-config.ts` -> shape menu organization; likely shape feature scope

Reason for separation:

- Potential leakage from commit-based extraction.
- Some are likely connector-adjacent or tooling churn rather than strict connector runtime requirements.

Reduction protocol:

1. Disable/remove this patch layer.
2. Build and run connector test subset.
3. Re-add only files proven necessary.
