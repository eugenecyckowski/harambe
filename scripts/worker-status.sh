#!/bin/bash
# worker-status.sh — list active worker-* tmux sessions with cwd + last lines.
# Output is intentionally short and narrow so it's phone-readable.
#
# Each entry:
#   ● worker-<repo>-<slug>  [Nm idle]
#     ~/repos/<repo>/<user>/<slug>
#     last:
#       > ...
#       > ...

set -euo pipefail

# tmux session-name format string: name <TAB> activity-timestamp
sessions="$(tmux list-sessions -F '#{session_name}	#{session_activity}' 2>/dev/null \
  | awk -F'\t' '$1 ~ /^worker-/ { print }' || true)"

if [ -z "$sessions" ]; then
  echo "No workers."
  exit 0
fi

now=$(date +%s)
first=1

while IFS=$'\t' read -r name activity; do
  [ $first -eq 1 ] || echo ""
  first=0

  # idle time in human-friendly form
  idle=$(( now - activity ))
  if   [ $idle -lt 60 ];    then idle_str="${idle}s idle"
  elif [ $idle -lt 3600 ];  then idle_str="$((idle/60))m idle"
  else                            idle_str="$((idle/3600))h idle"
  fi

  cwd="$(tmux display-message -p -t "$name" '#{pane_current_path}' 2>/dev/null || echo '?')"
  cwd_short="${cwd/#$HOME/~}"

  echo "● $name  [$idle_str]"
  echo "  $cwd_short"
  echo "  last:"

  # Capture a generous window so we can drop blank lines (TUI draws lots of
  # whitespace) and still surface 5 lines of real output.
  tmux capture-pane -t "$name" -p -S -50 2>/dev/null \
    | sed '/^[[:space:]]*$/d' \
    | tail -5 \
    | sed 's/^/    > /'
done <<< "$sessions"
