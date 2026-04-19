#!/bin/bash
# overlay/setup/<repo>.sh — per-repo worktree setup hook.
#
# Rename this file to match the repo name, e.g. overlay/setup/my-app.sh,
# make it executable (chmod +x), and fill in whatever needs to happen after
# a fresh worktree is created for that repo.
#
# Runs with:
#   CWD = the new worktree
#   $HARAMBE_REPO     = the repo name (e.g. "my-app")
#   $HARAMBE_WORKTREE = absolute worktree path

set -euo pipefail

# Example 1 — carry a personal overlay file into every worktree
if [ -f "$HOME/repos/$HARAMBE_REPO/CLAUDE.local.md" ]; then
  cp "$HOME/repos/$HARAMBE_REPO/CLAUDE.local.md" CLAUDE.local.md
  echo "  copied CLAUDE.local.md"
fi

# Example 2 — install deps
# yarn install --silent

# Example 3 — symlink node_modules from the main repo (disk-cheap)
# if [ -d "$HOME/repos/$HARAMBE_REPO/node_modules" ] && [ ! -e node_modules ]; then
#   ln -s "$HOME/repos/$HARAMBE_REPO/node_modules" node_modules
# fi

# Example 4 — copy a .env
# if [ -f "$HOME/repos/$HARAMBE_REPO/.env.local" ] && [ ! -e .env.local ]; then
#   cp "$HOME/repos/$HARAMBE_REPO/.env.local" .env.local
# fi
