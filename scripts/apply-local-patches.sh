#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
  echo "Usage: $0 <repo-path> <patch-root> [patches-required=true|false]"
  echo "Example: $0 /affine /tmp/affine-patches true"
  exit 1
fi

REPO_PATH="$1"
PATCH_ROOT="$2"
PATCHES_REQUIRED="${3:-true}"

if [ ! -d "$REPO_PATH/.git" ]; then
  echo "Error: $REPO_PATH is not a git repository"
  exit 1
fi

if ! git -C "$REPO_PATH" config user.name >/dev/null 2>&1; then
  git -C "$REPO_PATH" config user.name "${GIT_USER_NAME:-AFFiNE Docker Builder}"
fi
if ! git -C "$REPO_PATH" config user.email >/dev/null 2>&1; then
  git -C "$REPO_PATH" config user.email "${GIT_USER_EMAIL:-affine-docker-builder@local}"
fi

if [ ! -d "$PATCH_ROOT" ]; then
  if [ "$PATCHES_REQUIRED" = "true" ]; then
    echo "Error: patch directory not found: $PATCH_ROOT"
    exit 1
  fi
  echo "No patch directory found; skipping patch apply"
  exit 0
fi

mapfile -t PATCH_FILES < <(find "$PATCH_ROOT" -type f -name '*.patch' | sort)

if [ "${#PATCH_FILES[@]}" -eq 0 ]; then
  if [ "$PATCHES_REQUIRED" = "true" ]; then
    echo "Error: no patch files found under: $PATCH_ROOT"
    exit 1
  fi
  echo "No patch files found; skipping patch apply"
  exit 0
fi

echo "=== Applying local patches ==="
echo "Patch root: $PATCH_ROOT"
echo "Patch count: ${#PATCH_FILES[@]}"
git -C "$REPO_PATH" show -s --oneline HEAD

for patch in "${PATCH_FILES[@]}"; do
  echo "Applying patch: $(basename "$patch")"
  if ! git -C "$REPO_PATH" am --3way "$patch"; then
    echo "Patch apply failed: $patch"
    git -C "$REPO_PATH" status --short || true
    git -C "$REPO_PATH" diff --name-only --diff-filter=U || true
    git -C "$REPO_PATH" am --abort || true
    exit 1
  fi
done

echo "=== Final composed HEAD ==="
git -C "$REPO_PATH" show -s --oneline HEAD
