# Local Patch Packs

Store `.patch` files here to apply custom AFFiNE changes during Docker builds.

Recommended layout:

- `patches/01-host-hooks/*.patch`
- `patches/05-connector-core/*.patch`

Patches are discovered recursively and applied in lexical order.

Build args:

- `APPLY_LOCAL_PATCHES=true` to enable patch application.
- `PATCHES_REQUIRED=true` to fail build when no patches are found.
