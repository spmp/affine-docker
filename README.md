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

Mode switch:

- `APPLY_PRIVATE_BRANCHES=true` -> branch-compose mode
- `APPLY_PRIVATE_BRANCHES=false` (default) -> local patch mode

## Main files

- `Dockerfile` - main build/runtime image definition
- `scripts/apply-local-patches.sh` - applies `.patch` files via `git am --3way`
- `scripts/compose-private-branches.sh` - optional branch composition helper
- `patches/` - patch packs (recursive, lexical apply order)

## Default repos/branches

- Upstream AFFiNE source:
- `GIT_REPO=https://github.com/toeverything/AFFiNE.git`
- `GIT_TAG=canary`
- `GIT_DEPTH=0` (full history; recommended for reliable `git am --3way`)
- `BUILD_VERSION=` (optional SemVer override, e.g. `0.26.3-canary.1`)
- `GIT_USER_NAME=AFFiNE Docker Builder`
- `GIT_USER_EMAIL=affine-docker-builder@local`
- `PATCH_INCLUDE=` (optional comma list; match by number/prefix/full name)
- `PATCH_EXCLUDE=` (optional comma list; same matching rules)
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
- `patches/05-connector-runtime/*.patch`
- `patches/06-connector-support-uncertain/*.patch`

Current bucket intent:

- `01-host-hooks`: private platform seams and compose scripts.
- `02-color-palettes`: color palette support for drawing, including settings and customisations
- `03-dotted-line-style`: dotted line style
- `05-connector-runtime`: connector drawing features
- `06-connector-hover-initiation`: hover on shape to initiate connector

Ordering rule:

- All `.patch` files under `patches/` are applied recursively.
- Apply order is case-insensitive lexical order (`0-9A-Z`, case not significant).
- Use numeric prefixes to control phase ordering (`01-`, `05-`, `10-`, etc.).

Build command:

```bash
docker build \
  -f Dockerfile \
  -t affine:local-patched \
  --build-arg GIT_REPO=https://github.com/toeverything/AFFiNE.git \
  --build-arg GIT_TAG=canary \
  --build-arg GIT_DEPTH=0 \
  --build-arg GIT_USER_NAME="AFFiNE Docker Builder" \
  --build-arg GIT_USER_EMAIL="affine-docker-builder@local" \
  --build-arg TOOLING_REPO=https://github.com/spmp/affine-docker.git \
  --build-arg TOOLING_REF=main \
  --build-arg APPLY_PRIVATE_BRANCHES=false \
  --build-arg PATCHES_REQUIRED=true \
  .
```

Patch selection examples:

```bash
# Apply only host-hooks and connector runtime
--build-arg PATCH_INCLUDE=01,05-connector-runtime

# Apply all except uncertain support layer
--build-arg PATCH_EXCLUDE=06-connector-support-uncertain

# Apply only one exact patch by filename prefix
--build-arg PATCH_INCLUDE=0001-feat-connector-curated-runtime-core
```

Manual script usage (outside Docker build):

```bash
scripts/apply-local-patches.sh \
  --repo-path /tmp/affine \
  --patch-root /tmp/affine-docker-tooling/patches \
  --patches-required true \
  --include-csv 01,05 \
  --exclude-csv 07-flips
```

Notes:

- Patches are applied recursively from `${TOOLING_PATCH_DIR}` (default `patches`).
- Apply order is case-insensitive lexical by file path (`0-9A-Z`, case not significant).
- Build fails fast on patch conflicts and prints conflict files.
- For deterministic patch builds, prefer pinning `GIT_TAG` to the commit your patch pack was generated from.
- If you set `BUILD_VERSION`, it must be valid SemVer. Values like `canary` are invalid and can break auth/runtime flows.
- If using local patches, keep host hooks in an earlier lexical path (e.g. `01-host-hooks`) so they apply before feature packs.

## Optional workflow (branch composition)

You can compose branches from a private fork during build:

- `APPLY_PRIVATE_BRANCHES=true`
- `PRIVATE_REPO=https://github.com/spmp/AFFiNE.git` (default)
- `HOST_HOOKS_BRANCH=platform/host-hooks`
- `EXT_BRANCHES=ext/connector-kit,ext/another-feature`

This mode is stricter and requires clean branch ancestry.

Branch compose order:

1. Host hooks branch is applied first.
2. Extension branches are applied in the exact order listed in `EXT_BRANCHES`.

Important:

- Branch mode and patch mode are mutually exclusive by design.
