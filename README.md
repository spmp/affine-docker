# affine-docker

Docker build setup for running a self-hosted AFFiNE image with optional customizations.

Design goal: the `Dockerfile` is sufficient. Scripts and patch packs are pulled by git during build.

## Attribution

This setup is originally based on work by **Sander Sneekes**:

- Blog post: https://sneekes.app/posts/building_a_production_ready-_affine_docker_image_with_custom-_ai_models/

## What this repo does

- Clones AFFiNE from a configurable repo/branch at build time.
- Pulls tooling (scripts + patches) from a configurable tooling repo.
- Builds server + web/admin/mobile artifacts.
- Optionally applies patch packs before build.
- Optionally composes private branches (host hooks + extensions from your fork).

## Main files

- `Dockerfile` - main build/runtime image definition
- `scripts/apply-local-patches.sh` - applies `.patch` files via `git am --3way`
- `scripts/compose-private-branches.sh` - optional branch composition helper
- `patches/` - patch packs (recursive, lexical apply order)

## Default repos/branches

- Upstream AFFiNE source:
- `GIT_REPO=https://github.com/toeverything/AFFiNE.git`
- `GIT_TAG=canary`
- `GIT_USER_NAME=AFFiNE Docker Builder`
- `GIT_USER_EMAIL=affine-docker-builder@local`
- Tooling + patches source:
  - `TOOLING_REPO=https://github.com/spmp/affine-docker.git`
  - `TOOLING_REF=main`
- Private extension source:
  - `PRIVATE_REPO=https://github.com/spmp/AFFiNE.git`
  - `HOST_HOOKS_BRANCH=platform/host-hooks`

## Recommended workflow (patch packs)

Keep custom changes as patch files in the tooling repo (`TOOLING_REPO`) under `patches/`.

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
  --build-arg GIT_USER_NAME="AFFiNE Docker Builder" \
  --build-arg GIT_USER_EMAIL="affine-docker-builder@local" \
  --build-arg TOOLING_REPO=https://github.com/spmp/affine-docker.git \
  --build-arg TOOLING_REF=main \
  --build-arg APPLY_LOCAL_PATCHES=true \
  --build-arg PATCHES_REQUIRED=true \
  .
```

Notes:

- Patches are applied recursively from `${TOOLING_PATCH_DIR}` (default `patches`).
- Apply order is lexical by file path.
- Build fails fast on patch conflicts and prints conflict files.

## Optional workflow (branch composition)

You can compose branches from a private fork during build:

- `APPLY_PRIVATE_BRANCHES=true`
- `PRIVATE_REPO=https://github.com/spmp/AFFiNE.git` (default)
- `HOST_HOOKS_BRANCH=platform/host-hooks`
- `EXT_BRANCHES=ext/connector-kit,ext/another-feature`

This mode is stricter and requires clean branch ancestry.
