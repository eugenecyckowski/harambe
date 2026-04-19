#!/bin/bash
# Harambe watchdog — monitors for a reset trigger file and restarts Claude
# Code inside the tmux session when it appears. Uses `tmux respawn-pane -k`
# which atomically kills whatever's running in the pane and replaces it with
# a fresh command — no PID hunting required.
#
# After respawn, the watchdog waits for Claude to finish booting, then
# auto-types `/remote-control` so the new session comes up ready for the
# phone to reconnect.

SESSION="harambe"
TRIGGER="/tmp/harambe-reset"
TRIGGER_SILENT="/tmp/harambe-reset-silent"
LOG="/tmp/harambe-watchdog.log"
BOOT_WAIT=10  # seconds Claude takes to finish loading plugins/skills before it accepts input
GREET_WAIT=3  # seconds to let /remote-control settle before sending the greeting prompt
GREET_PROMPT='Wake up Harambe'

# Session names: harambe-<adjective>-<food>, e.g. harambe-zesty-tomato-soup.
ADJECTIVES=(
  zesty crispy spicy tangy smoky salty buttery toasty crunchy fluffy
  sticky gooey molten golden sizzling charred pickled fermented braised
  caramelized whipped forbidden cursed legendary suspicious unhinged
  chaotic dubious rogue contraband tactical nuclear audacious volcanic
)
FOODS=(
  tomato-soup pineapple-pizza lettuce-wrap meatball-sub taco-supreme
  pickle-jar dumpling-stack croissant-tower bagel-throne waffle-house
  pancake-avalanche burrito-bomb pretzel-logic cupcake-heist donut-wall
  nugget-empire samosa-fortress pierogi-parade gnocchi-avalanche
  lasagna-cathedral risotto-volcano paella-bonanza curry-tsunami
  kebab-express falafel-factory hummus-kingdom churro-stampede
  empanada-riot tamale-conspiracy gyoza-battalion ramen-monsoon
  sushi-typhoon tempura-blizzard jambalaya-uprising fondue-fountain
  brioche-rebellion crumpet-insurgency pavlova-tornado
)

generate_session_name() {
  local adj="${ADJECTIVES[$RANDOM % ${#ADJECTIVES[@]}]}"
  local food="${FOODS[$RANDOM % ${#FOODS[@]}]}"
  echo "harambe-${adj}-${food}"
}

build_cmd() {
  local name
  name=$(generate_session_name)
  log "  session name: $name"
  echo "claude --dangerously-skip-permissions -n \"$name\""
}

log() { echo "$(date '+%Y-%m-%d %H:%M:%S'): $*" >> "$LOG"; }

enter_remote_control() {
  # $1 = "greet" or "silent". In silent mode we skip the "Wake up Harambe"
  # greeting so heartbeat auto-resets don't spam the pane.
  local mode="${1:-greet}"
  log "  waiting ${BOOT_WAIT}s for Claude to boot..."
  sleep "$BOOT_WAIT"
  log "  sending /remote-control"
  tmux send-keys -t "$SESSION" '/remote-control' Enter 2>>"$LOG"
  log "  /remote-control sent"
  if [ "$mode" = "silent" ]; then
    log "  silent reset — skipping greeting"
    return
  fi
  log "  waiting ${GREET_WAIT}s for /remote-control to settle..."
  sleep "$GREET_WAIT"
  log "  sending greeting prompt"
  # Send text and Enter separately — Claude Code's TUI detects rapid multi-char
  # input as a paste and folds a same-call Enter into the paste buffer (= a
  # literal newline) instead of submitting. A brief sleep between them lets the
  # paste settle so Enter actually triggers submit.
  tmux send-keys -t "$SESSION" "$GREET_PROMPT" 2>>"$LOG"
  sleep 0.3
  tmux send-keys -t "$SESSION" Enter 2>>"$LOG"
  log "  greeting prompt sent"
}

log "Watchdog started. Monitoring $TRIGGER (and $TRIGGER_SILENT) for session '$SESSION'"

while true; do
  MODE=""
  # Silent trigger takes priority — if both appear in the same tick window,
  # treat it as an auto-reset (no greeting). Manual resets can re-trigger.
  if [ -f "$TRIGGER_SILENT" ]; then
    MODE="silent"
    rm -f "$TRIGGER_SILENT"
  elif [ -f "$TRIGGER" ]; then
    MODE="greet"
    rm -f "$TRIGGER"
  fi

  if [ -n "$MODE" ]; then
    log "Reset triggered (mode: $MODE)."

    CMD=$(build_cmd)

    if tmux has-session -t "$SESSION" 2>/dev/null; then
      # respawn-pane -k: kill current process in pane, start fresh command.
      # Atomic — no race between kill and relaunch, no orphaned processes.
      if tmux respawn-pane -k -t "$SESSION" "$CMD" 2>>"$LOG"; then
        log "Claude Code restarted in session '$SESSION'"
        enter_remote_control "$MODE"
      else
        log "respawn-pane failed — recreating session"
        tmux kill-session -t "$SESSION" 2>/dev/null
        tmux new-session -d -s "$SESSION" "$CMD"
        enter_remote_control "$MODE"
      fi
    else
      tmux new-session -d -s "$SESSION" "$CMD"
      log "Created new tmux session '$SESSION' with Claude Code"
      enter_remote_control "$MODE"
    fi
  fi
  sleep 5
done
