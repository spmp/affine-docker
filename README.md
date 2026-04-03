# affine-docker

Docker build setup for running a self-hosted AFFiNE image with optional customizations.

## Attribution

This setup is originally based on work by **Sander Sneekes**:

- Blog post: https://sneekes.app/posts/building_a_production_ready-_affine_docker_image_with_custom-_ai_models/

## What this repo does

- Clones AFFiNE from a configurable repo/branch at build time.
- Builds server + web/admin/mobile artifacts.
- Optionally applies local patch packs before build.
- Optionally composes private branches (host hooks + extensions).

## Main files

- `Dockerfile` - main build/runtime image definition
- `scripts/apply-local-patches.sh` - applies `.patch` files via `git am --3way`
- `scripts/compose-private-branches.sh` - optional branch composition helper
- `patches/` - local patch packs (recursive, lexical apply order)

## Recommended workflow (local patches)

Keep custom changes as patch files inside this repo.

Suggested layout:

- `patches/01-host-hooks/*.patch`
- `patches/05-connector-core/*.patch`

Build command:

```bash
docker build \
  -f Dockerfile \
  -t affine:local-patched \
  --build-arg GIT_REPO=https://github.com/toeverything/AFFiNE.git \
  --build-arg GIT_TAG=canary \
  --build-arg APPLY_LOCAL_PATCHES=true \
  --build-arg PATCHES_REQUIRED=true \
  .
```

Notes:

- Patches are applied recursively from `patches/`.
- Apply order is lexical by file path.
- Build fails fast on patch conflicts and prints conflict files.

## Optional workflow (branch composition)

You can compose branches from a private fork during build:

- `APPLY_PRIVATE_BRANCHES=true`
- `PRIVATE_REPO=<your-fork-url>`
- `HOST_HOOKS_BRANCH=platform/host-hooks`
- `EXT_BRANCHES=ext/connector-kit,ext/another-feature`

This mode is stricter and requires clean branch ancestry.
