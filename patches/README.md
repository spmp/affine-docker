# Local Patch Packs

Store `.patch` files here to apply custom AFFiNE changes during Docker builds.

Recommended layout:

- `patches/01-host-hooks/*.patch`
- `patches/05-connector-core/*.patch`

Patches are discovered recursively and applied in lexical order.

Ordering is case-insensitive lexical (`0-9A-Z`, case not significant).
Use numeric directory prefixes to enforce phase order.

Build args:

- `APPLY_PRIVATE_BRANCHES=false` to use local patch application mode (default).
- `PATCHES_REQUIRED=true` to fail build when no patches are found.
