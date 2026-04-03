#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 4 ] || [ "$#" -gt 5 ]; then
  echo "Usage: $0 <repo-path> <base-ref> <private-repo-url> <host-hooks-branch> [ext-branches-csv]"
  echo "Example: $0 /affine origin/canary https://github.com/spmp/AFFiNE.git platform/host-hooks ext/connector-kit,ext/grid-snap"
  exit 1
fi

REPO_PATH="$1"
BASE_REF="$2"
PRIVATE_REPO_URL="$3"
HOST_HOOKS_BRANCH="$4"
EXT_BRANCHES_CSV="${5:-}"

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

if ! git -C "$REPO_PATH" rev-parse --verify "$BASE_REF" >/dev/null 2>&1; then
  echo "Error: base ref not found: $BASE_REF"
  exit 1
fi

if git -C "$REPO_PATH" remote get-url private >/dev/null 2>&1; then
  git -C "$REPO_PATH" remote set-url private "$PRIVATE_REPO_URL"
else
  git -C "$REPO_PATH" remote add private "$PRIVATE_REPO_URL"
fi

git -C "$REPO_PATH" fetch private "$HOST_HOOKS_BRANCH"

HOST_BASE_REF="$BASE_REF"
if ! git -C "$REPO_PATH" merge-base --is-ancestor "$BASE_REF" "private/$HOST_HOOKS_BRANCH"; then
  HOST_BASE_REF="$(git -C "$REPO_PATH" merge-base "$BASE_REF" "private/$HOST_HOOKS_BRANCH")"
  echo "Warning: private/$HOST_HOOKS_BRANCH is not directly based on $BASE_REF"
  echo "Using merge-base for host range: $HOST_BASE_REF"
fi

echo "=== Base ref ==="
git -C "$REPO_PATH" show -s --oneline "$BASE_REF"

echo "=== Host hooks head ==="
git -C "$REPO_PATH" show -s --oneline "private/$HOST_HOOKS_BRANCH"

HOST_COMMITS="$(git -C "$REPO_PATH" rev-list --reverse --no-merges "$HOST_BASE_REF..private/$HOST_HOOKS_BRANCH")"
HOST_COUNT="$(printf '%s\n' "$HOST_COMMITS" | sed '/^$/d' | wc -l | tr -d ' ')"

echo "=== Host hooks commit count ==="
echo "$HOST_COUNT"

if [ "$HOST_COUNT" -gt 0 ]; then
  echo "=== Host hooks commits (last 10) ==="
  printf '%s\n' "$HOST_COMMITS" | tail -n 10 | while IFS= read -r sha; do
    [ -z "$sha" ] && continue
    git -C "$REPO_PATH" show -s --oneline "$sha"
  done
fi

for sha in $HOST_COMMITS; do
  echo "Applying host commit: $sha"
  if ! git -C "$REPO_PATH" cherry-pick "$sha"; then
    echo "Cherry-pick failed at host commit: $sha"
    git -C "$REPO_PATH" status --short || true
    git -C "$REPO_PATH" diff --name-only --diff-filter=U || true
    git -C "$REPO_PATH" cherry-pick --abort || true
    exit 1
  fi
done

if [ -n "$EXT_BRANCHES_CSV" ]; then
  IFS=',' read -ra EXT_BRANCHES <<< "$EXT_BRANCHES_CSV"
  for branch in "${EXT_BRANCHES[@]}"; do
    ext_branch="$(echo "$branch" | xargs)"
    if [ -z "$ext_branch" ]; then
      continue
    fi

    git -C "$REPO_PATH" fetch private "$ext_branch"

    EXT_BASE_REF="private/$HOST_HOOKS_BRANCH"
    if ! git -C "$REPO_PATH" merge-base --is-ancestor "private/$HOST_HOOKS_BRANCH" "private/$ext_branch"; then
      EXT_BASE_REF="$(git -C "$REPO_PATH" merge-base "private/$HOST_HOOKS_BRANCH" "private/$ext_branch")"
      echo "Warning: private/$ext_branch is not directly based on private/$HOST_HOOKS_BRANCH"
      echo "Using merge-base for extension range ($ext_branch): $EXT_BASE_REF"
    fi

    echo "=== Extension head ($ext_branch) ==="
    git -C "$REPO_PATH" show -s --oneline "private/$ext_branch"

    EXT_COMMITS="$(git -C "$REPO_PATH" rev-list --reverse --no-merges "$EXT_BASE_REF..private/$ext_branch")"
    EXT_COUNT="$(printf '%s\n' "$EXT_COMMITS" | sed '/^$/d' | wc -l | tr -d ' ')"

    echo "=== Extension commit count ($ext_branch) ==="
    echo "$EXT_COUNT"

    if [ "$EXT_COUNT" -gt 0 ]; then
      echo "=== Extension commits (last 10) ($ext_branch) ==="
      printf '%s\n' "$EXT_COMMITS" | tail -n 10 | while IFS= read -r sha; do
        [ -z "$sha" ] && continue
        git -C "$REPO_PATH" show -s --oneline "$sha"
      done
    fi

    for sha in $EXT_COMMITS; do
      echo "Applying extension commit ($ext_branch): $sha"
      if ! git -C "$REPO_PATH" cherry-pick "$sha"; then
        echo "Cherry-pick failed at extension commit: $sha (branch: $ext_branch)"
        git -C "$REPO_PATH" status --short || true
        git -C "$REPO_PATH" diff --name-only --diff-filter=U || true
        git -C "$REPO_PATH" cherry-pick --abort || true
        exit 1
      fi
    done
  done
fi

echo "=== Final composed HEAD ==="
git -C "$REPO_PATH" show -s --oneline HEAD
