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

is_shallow_repo() {
  test "$(git -C "$REPO_PATH" rev-parse --is-shallow-repository 2>/dev/null || echo false)" = "true"
}

for patch in "${PATCH_FILES[@]}"; do
  echo "Applying patch: $(basename "$patch")"
  if ! git -C "$REPO_PATH" am --3way "$patch"; then
    if is_shallow_repo; then
      echo "Patch failed on shallow clone. Fetching full history and retrying once..."
      git -C "$REPO_PATH" am --abort || true
      git -C "$REPO_PATH" fetch --unshallow || git -C "$REPO_PATH" fetch --depth=50000
      if git -C "$REPO_PATH" am --3way "$patch"; then
        continue
      fi
    fi
    echo "Patch apply failed: $patch"
    git -C "$REPO_PATH" status --short || true
    git -C "$REPO_PATH" diff --name-only --diff-filter=U || true
    echo "Hint: if building from floating canary, patch drift may occur. Pin GIT_TAG to the patch base commit or regenerate patches against latest canary."
    git -C "$REPO_PATH" am --abort || true
    exit 1
  fi
done

echo "=== Final composed HEAD ==="
git -C "$REPO_PATH" show -s --oneline HEAD
