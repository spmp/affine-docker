#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 --repo-path <path> --patch-root <path> [--patches-required true|false] [--include-csv csv] [--exclude-csv csv]"
  echo ""
  echo "Examples:"
  echo "  $0 --repo-path /affine --patch-root /tmp/affine-patches"
  echo "  $0 --repo-path /affine --patch-root /tmp/affine-patches --patches-required true --include-csv 01,05-connector-runtime --exclude-csv 07-connector-tests"
  echo ""
  echo "Legacy positional form is still supported for compatibility:"
  echo "  $0 <repo-path> <patch-root> [patches-required=true|false] [include-csv] [exclude-csv]"
}

REPO_PATH=""
PATCH_ROOT=""
PATCHES_REQUIRED="true"
PATCH_INCLUDE=""
PATCH_EXCLUDE=""

if [ "$#" -eq 0 ]; then
  usage
  exit 1
fi

if [[ "$1" == -* ]]; then
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --repo-path)
        REPO_PATH="${2:-}"
        shift 2
        ;;
      --repo-path=*)
        REPO_PATH="${1#*=}"
        shift
        ;;
      --patch-root)
        PATCH_ROOT="${2:-}"
        shift 2
        ;;
      --patch-root=*)
        PATCH_ROOT="${1#*=}"
        shift
        ;;
      --patches-required)
        PATCHES_REQUIRED="${2:-}"
        shift 2
        ;;
      --patches-required=*)
        PATCHES_REQUIRED="${1#*=}"
        shift
        ;;
      --include-csv)
        PATCH_INCLUDE="${2:-}"
        shift 2
        ;;
      --include-csv=*)
        PATCH_INCLUDE="${1#*=}"
        shift
        ;;
      --exclude-csv)
        PATCH_EXCLUDE="${2:-}"
        shift 2
        ;;
      --exclude-csv=*)
        PATCH_EXCLUDE="${1#*=}"
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "Error: unknown argument '$1'"
        usage
        exit 1
        ;;
    esac
  done
else
  if [ "$#" -lt 2 ] || [ "$#" -gt 5 ]; then
    usage
    exit 1
  fi

  REPO_PATH="$1"
  PATCH_ROOT="$2"
  PATCHES_REQUIRED="${3:-true}"
  PATCH_INCLUDE="${4:-}"
  PATCH_EXCLUDE="${5:-}"
fi

if [ -z "$REPO_PATH" ] || [ -z "$PATCH_ROOT" ]; then
  echo "Error: --repo-path and --patch-root are required"
  usage
  exit 1
fi

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

is_mailbox_patch() {
  local patch="$1"
  local first_line=""
  IFS= read -r first_line < "$patch" || true
  [[ "$first_line" == From\ * ]]
}

apply_diff_patch() {
  local patch="$1"
  local rel_patch="$2"

  if ! git -C "$REPO_PATH" apply --3way --index "$patch"; then
    return 1
  fi

  if git -C "$REPO_PATH" diff --cached --quiet; then
    echo "No staged changes after applying diff patch: $rel_patch"
    return 1
  fi

  git -C "$REPO_PATH" commit --no-verify -m "Apply patch: $rel_patch" >/dev/null
  return 0
}

print_rejected_hunks() {
  local patch="$1"
  local tmp_worktree
  tmp_worktree="$(mktemp -d)"

  if ! git -C "$REPO_PATH" worktree add --detach "$tmp_worktree" HEAD >/dev/null 2>&1; then
    rm -rf "$tmp_worktree"
    return 0
  fi

  git -C "$tmp_worktree" apply --reject --whitespace=nowarn "$patch" >/dev/null 2>&1 || true

  echo "--- rejected hunks (.rej) ---"
  shopt -s globstar nullglob
  local rej_files=("$tmp_worktree"/**/*.rej)
  if [ "${#rej_files[@]}" -eq 0 ]; then
    echo "No .rej files produced by git apply --reject"
  else
    for rej in "${rej_files[@]}"; do
      local rel
      rel="${rej#${tmp_worktree}/}"
      echo "File: $rel"
      sed -n '1,200p' "$rej" || true
    done
  fi
  shopt -u globstar nullglob
  echo "--- end rejected hunks ---"

  git -C "$REPO_PATH" worktree remove --force "$tmp_worktree" >/dev/null 2>&1 || rm -rf "$tmp_worktree"
}

for patch in "${PATCH_FILES[@]}"; do
  rel_patch="${patch#${PATCH_ROOT}/}"
  echo "Applying patch: $(basename "$patch")"
  echo "Patch path: $rel_patch"
  echo "HEAD before apply: $(git -C "$REPO_PATH" rev-parse --short HEAD)"

  applied=false
  if is_mailbox_patch "$patch"; then
    if git -C "$REPO_PATH" am --3way "$patch"; then
      applied=true
    fi
  else
    if apply_diff_patch "$patch" "$rel_patch"; then
      applied=true
    fi
  fi

  if [ "$applied" = false ]; then
    echo "Patch failed with 3-way apply: $rel_patch"
    echo "--- git am current patch (summary) ---"
    git -C "$REPO_PATH" am --show-current-patch=diff || true
    echo "--- end current patch ---"
    git -C "$REPO_PATH" am --abort >/dev/null 2>&1 || true

    if ! is_mailbox_patch "$patch"; then
      echo "--- git apply --3way --index (retry) ---"
      git -C "$REPO_PATH" apply --3way --index "$patch" || true
      git -C "$REPO_PATH" reset --hard HEAD >/dev/null 2>&1 || true
      echo "--- end git apply --3way --index ---"
    fi

    echo "--- git apply --check (verbose) ---"
    git -C "$REPO_PATH" apply --check --verbose "$patch" || true
    echo "--- end git apply --check ---"
    print_rejected_hunks "$patch"

    if is_shallow_repo; then
      echo "Patch failed on shallow clone. Fetching full history and retrying once..."
      git -C "$REPO_PATH" am --abort || true
      git -C "$REPO_PATH" fetch --unshallow || git -C "$REPO_PATH" fetch --depth=50000
      if is_mailbox_patch "$patch"; then
        if git -C "$REPO_PATH" am --3way "$patch"; then
          echo "Patch retry succeeded after unshallow: $rel_patch"
          continue
        fi
      else
        if apply_diff_patch "$patch" "$rel_patch"; then
          echo "Patch retry succeeded after unshallow: $rel_patch"
          continue
        fi
      fi
    fi
    echo "Patch apply failed: $patch"
    echo "HEAD at failure: $(git -C "$REPO_PATH" rev-parse --short HEAD)"
    git -C "$REPO_PATH" status --short || true
    git -C "$REPO_PATH" diff --name-only --diff-filter=U || true
    echo "Hint: if building from floating canary, patch drift may occur. Pin GIT_TAG to the patch base commit or regenerate patches against latest canary."
    git -C "$REPO_PATH" am --abort || true
    exit 1
  fi
done

echo "=== Final composed HEAD ==="
git -C "$REPO_PATH" show -s --oneline HEAD
