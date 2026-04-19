#!/bin/bash
# heartbeat-tick.sh — launchd-invoked heartbeat for Harambe.
#
# Flow:
#   1. If state/heartbeat-paused exists → log "skipped: paused", exit 0
#   2. If tmux session $HEARTBEAT_SESSION missing → log "skipped: no session", exit 0
#   3. If window activity within last $HEARTBEAT_QUIET_SECONDS → log "skipped: recent activity", exit 0
#   4. Else → tmux send-keys "heartbeat" Enter, log "fired"
#
# Flags:
#   --dry-run   run all checks but don't send keys; log "would fire" instead of "fired"
#   --force     skip the quiet-window check (used by `harambe heartbeat` manual fire)
#
# Env overrides (for tests):
#   HEARTBEAT_SESSION          default: harambe
#   HEARTBEAT_STATE_DIR        default: ~/repos/harambe/state
#   HEARTBEAT_QUIET_SECONDS    default: 180

set -euo pipefail

SESSION="${HEARTBEAT_SESSION:-harambe}"
STATE_DIR="${HEARTBEAT_STATE_DIR:-$HOME/repos/harambe/state}"
QUIET_SECONDS="${HEARTBEAT_QUIET_SECONDS:-180}"

PAUSE_FILE="$STATE_DIR/heartbeat-paused"
LOG_FILE="$STATE_DIR/heartbeat.log"

DRY_RUN=0
FORCE=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --force)   FORCE=1 ;;
    *) echo "error: unknown flag '$arg'" >&2; exit 2 ;;
  esac
done

mkdir -p "$STATE_DIR"

log() {
  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "$ts $*" >> "$LOG_FILE"
}

# 1. paused
if [ -f "$PAUSE_FILE" ]; then
  log "skipped: paused"
  exit 0
fi

# 2. no session
if ! tmux has-session -t "$SESSION" 2>/dev/null; then
  log "skipped: no session ($SESSION)"
  exit 0
fi

# 3. recent activity (unless --force)
if [ "$FORCE" -eq 0 ]; then
  last_activity="$(tmux display-message -p -t "$SESSION" -F '#{window_activity}' 2>/dev/null || echo 0)"
  # Strip anything non-numeric — tmux should always give us an integer, but
  # don't let a non-standard build trip the arithmetic below.
  last_activity="${last_activity//[^0-9]/}"
  last_activity="${last_activity:-0}"
  now="$(date +%s)"
  delta=$((now - last_activity))
  if [ "$delta" -lt "$QUIET_SECONDS" ]; then
    log "skipped: recent activity (${delta}s ago)"
    exit 0
  fi
fi

# 4. fire (or would-fire)
if [ "$DRY_RUN" -eq 1 ]; then
  log "would fire"
  exit 0
fi

tmux send-keys -t "$SESSION" "heartbeat" Enter
log "fired"
