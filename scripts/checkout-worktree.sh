#!/bin/bash
# checkout-worktree.sh — check out an existing remote branch as a worktree.
#
# Usage: checkout-worktree.sh <repo> <branch>
#
# Creates a worktree at ~/repos/<repo>/<user>/<slug>/ where
# <slug> = <branch> with '/' replaced by '-' (so feature/foo -> feature-foo)
# and <user> defaults to $USER (override with HARAMBE_USER_DIR).
# The local branch tracks origin/<branch>.
#
# After the worktree is created, runs the optional overlay setup hook at
# $HARAMBE_ROOT/overlay/setup/<repo>.sh if one exists (e.g. copy personal
# config, install deps). See overlay.example/ for the pattern.
#
# Use this when:
#   - someone else's branch lives at origin/<branch> and you want to read or
#     work in it locally
#   - a local branch already exists and you want a fresh worktree for it
#
# For starting a NEW branch and spawning a worker Claude on it, use
# spawn-worker.sh instead.

set -euo pipefail

if [ $# -ne 2 ]; then
  echo "Usage: $0 <repo> <branch>" >&2
  echo "Example: $0 my-app feature/new-thing" >&2
  exit 1
fi

REPO="$1"
BRANCH="$2"
SLUG="$(echo "$BRANCH" | tr '/' '-')"
USER_DIR="${HARAMBE_USER_DIR:-$USER}"

MAIN_REPO="$HOME/repos/$REPO"
WORKTREE="$MAIN_REPO/$USER_DIR/$SLUG"
HARAMBE_ROOT="${HARAMBE_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

# -- sanity checks ----------------------------------------------------------

if [ ! -e "$MAIN_REPO/.git" ]; then
  echo "error: $MAIN_REPO doesn't look like a git repo." >&2
  exit 1
fi

if [ -e "$WORKTREE" ]; then
  echo "error: worktree path already exists: $WORKTREE" >&2
  echo "       remove: git -C $MAIN_REPO worktree remove $WORKTREE" >&2
  exit 1
fi

# -- fetch & verify branch exists ------------------------------------------

echo "Fetching origin/$BRANCH..."
# Try targeted fetch first; fall back to full fetch if the branch arg fails
# (e.g. if origin/<branch> hasn't been seen by this clone yet).
git -C "$MAIN_REPO" fetch origin "$BRANCH" 2>/dev/null || git -C "$MAIN_REPO" fetch origin

if ! git -C "$MAIN_REPO" rev-parse --verify "refs/remotes/origin/$BRANCH" >/dev/null 2>&1; then
  echo "error: origin/$BRANCH doesn't exist after fetch." >&2
  exit 1
fi

# -- create worktree --------------------------------------------------------

if git -C "$MAIN_REPO" rev-parse --verify "refs/heads/$BRANCH" >/dev/null 2>&1; then
  echo "Local branch '$BRANCH' already exists; checking out at $WORKTREE"
  git -C "$MAIN_REPO" worktree add "$WORKTREE" "$BRANCH" >/dev/null
else
  echo "Creating local branch '$BRANCH' tracking origin/$BRANCH at $WORKTREE"
  git -C "$MAIN_REPO" worktree add --track -b "$BRANCH" "$WORKTREE" "origin/$BRANCH" >/dev/null
fi

# -- run overlay setup hook if one exists -----------------------------------

HOOK="$HARAMBE_ROOT/overlay/setup/$REPO.sh"
if [ -x "$HOOK" ]; then
  echo ""
  echo "Running overlay hook: $HOOK"
  ( cd "$WORKTREE" && HARAMBE_REPO="$REPO" HARAMBE_WORKTREE="$WORKTREE" "$HOOK" ) || \
    echo "  (hook exited non-zero; continuing anyway)"
fi

cat <<EOF

Worktree ready.
  path:   $WORKTREE
  branch: $BRANCH (tracks origin/$BRANCH)

  cd $WORKTREE
EOF
