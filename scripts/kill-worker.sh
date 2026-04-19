#!/bin/bash
# kill-worker.sh — tear down a tmux-native worker cleanly.
#
# Usage: kill-worker.sh <session> [--delete-branch]
#
# Example: kill-worker.sh worker-my-app-fix-toolbar
#          kill-worker.sh worker-my-app-fix-toolbar --delete-branch
#
# Does three things in order:
#   1. tmux kill-session -t <session>
#   2. git worktree remove --force <worktree>
#   3. (if --delete-branch) git branch -D <branch>
#
# The worktree path and branch are discovered from the live tmux session, so
# the caller only needs the session name (which is what worker-status.sh shows).
#
# By default the branch is KEPT — it's usually a PR branch in flight. Pass
# --delete-branch only when nothing was shipped and you want a clean nuke.

set -euo pipefail

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
  echo "Usage: $0 <session> [--delete-branch]" >&2
  echo "Example: $0 worker-my-app-fix-toolbar" >&2
  exit 1
fi

SESSION="$1"
DELETE_BRANCH=0
if [ "${2:-}" = "--delete-branch" ]; then
  DELETE_BRANCH=1
elif [ -n "${2:-}" ]; then
  echo "error: unknown flag '$2'. Only --delete-branch is accepted." >&2
  exit 1
fi

# -- discover worktree + branch from the live session ----------------------

if ! tmux has-session -t "$SESSION" 2>/dev/null; then
  echo "error: no tmux session named '$SESSION'." >&2
  echo "       list workers: ~/repos/harambe/scripts/worker-status.sh" >&2
  exit 1
fi

WORKTREE="$(tmux display-message -p -t "$SESSION" '#{pane_current_path}' 2>/dev/null || true)"
if [ -z "$WORKTREE" ] || [ ! -d "$WORKTREE" ]; then
  echo "error: couldn't resolve worktree path from session '$SESSION' (cwd was: '$WORKTREE')." >&2
  exit 1
fi

# rev-parse gives us a reliable pointer to the main repo's .git dir; parent of
# that is the main repo root. More robust than path string manipulation.
GIT_COMMON_DIR="$(git -C "$WORKTREE" rev-parse --git-common-dir 2>/dev/null || true)"
if [ -z "$GIT_COMMON_DIR" ]; then
  echo "error: '$WORKTREE' doesn't look like a git worktree." >&2
  exit 1
fi
# Resolve to absolute path (rev-parse can return a relative path)
GIT_COMMON_DIR="$(cd "$WORKTREE" && cd "$GIT_COMMON_DIR" && pwd)"
MAIN_REPO="$(dirname "$GIT_COMMON_DIR")"

BRANCH="$(git -C "$WORKTREE" branch --show-current 2>/dev/null || true)"

echo "Tearing down:"
echo "  session:  $SESSION"
echo "  worktree: $WORKTREE"
echo "  branch:   ${BRANCH:-(detached)}"
echo "  main:     $MAIN_REPO"
echo "  branch:   $([ $DELETE_BRANCH -eq 1 ] && echo 'WILL BE DELETED' || echo 'kept')"
echo ""

# -- kill session -----------------------------------------------------------

tmux kill-session -t "$SESSION"
echo "✓ killed tmux session"

# -- remove worktree --------------------------------------------------------

git -C "$MAIN_REPO" worktree remove --force "$WORKTREE"
echo "✓ removed worktree"

# Clean up empty parent dirs (<repo>/<user>/ and the old doubled-layout
# <repo>/<repo>/ if present). rmdir fails silently if non-empty — that's
# the right behavior; we only want to prune if it's genuinely empty.
parent="$(dirname "$WORKTREE")"
grandparent="$(dirname "$parent")"
rmdir "$parent" 2>/dev/null && echo "✓ pruned empty: $parent" || true
rmdir "$grandparent" 2>/dev/null && echo "✓ pruned empty: $grandparent" || true

# -- delete branch (optional) -----------------------------------------------

if [ $DELETE_BRANCH -eq 1 ] && [ -n "$BRANCH" ]; then
  git -C "$MAIN_REPO" branch -D "$BRANCH"
  echo "✓ deleted branch '$BRANCH'"
elif [ -n "$BRANCH" ]; then
  echo "• kept branch '$BRANCH' (pass --delete-branch to remove)"
fi

echo ""
echo "Done."
