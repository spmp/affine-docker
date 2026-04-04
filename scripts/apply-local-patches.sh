#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 2 ] || [ "$#" -gt 5 ]; then
  echo "Usage: $0 <repo-path> <patch-root> [patches-required=true|false] [include-csv] [exclude-csv]"
  echo "Example: $0 /affine /tmp/affine-patches true 01,05-connector-runtime 07-connector-tests"
  exit 1
fi

REPO_PATH="$1"
PATCH_ROOT="$2"
PATCHES_REQUIRED="${3:-true}"
PATCH_INCLUDE="${4:-}"
PATCH_EXCLUDE="${5:-}"

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

mapfile -t PATCH_FILES < <(find "$PATCH_ROOT" -type f -name '*.patch' | LC_ALL=C sort -f)

matches_token() {
  local token="$1"
  local rel="$2"
  local base="$3"
  local t="${token,,}"
  local r="${rel,,}"
  local b="${base,,}"

  [[ "$b" == "$t" ]] || \
    [[ "$b" == "$t"* ]] || \
    [[ "$r" == "$t" ]] || \
    [[ "$r" == "$t/"* ]] || \
    [[ "$r" == */"$t"/* ]] || \
    [[ "$r" == *"$t"* ]]
}

if [ -n "$PATCH_INCLUDE" ] || [ -n "$PATCH_EXCLUDE" ]; then
  mapfile -t FILTERED < <(
    for patch in "${PATCH_FILES[@]}"; do
      rel="${patch#${PATCH_ROOT}/}"
      base="$(basename "$patch")"

      include_ok=true
      if [ -n "$PATCH_INCLUDE" ]; then
        include_ok=false
        IFS=',' read -ra TOKENS <<< "$PATCH_INCLUDE"
        for token in "${TOKENS[@]}"; do
          token="$(echo "$token" | xargs)"
          [ -z "$token" ] && continue
          if matches_token "$token" "$rel" "$base"; then
            include_ok=true
            break
          fi
        done
      fi

      exclude_hit=false
      if [ -n "$PATCH_EXCLUDE" ]; then
        IFS=',' read -ra TOKENS <<< "$PATCH_EXCLUDE"
        for token in "${TOKENS[@]}"; do
          token="$(echo "$token" | xargs)"
          [ -z "$token" ] && continue
          if matches_token "$token" "$rel" "$base"; then
            exclude_hit=true
            break
          fi
        done
      fi

      if [ "$include_ok" = true ] && [ "$exclude_hit" = false ]; then
        printf '%s\n' "$patch"
      fi
    done
  )

  PATCH_FILES=("${FILTERED[@]}")
fi

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
if [ -n "$PATCH_INCLUDE" ]; then
  echo "Patch include filter: $PATCH_INCLUDE"
fi
if [ -n "$PATCH_EXCLUDE" ]; then
  echo "Patch exclude filter: $PATCH_EXCLUDE"
fi
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
