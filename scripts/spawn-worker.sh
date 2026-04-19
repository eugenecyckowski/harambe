#!/bin/bash
# spawn-worker.sh — spawn a tmux-native worker Claude in an isolated worktree.
#
# Usage: spawn-worker.sh [--remote-control] <repo> <slug> "<brief>"
#   --remote-control, -R: engage /remote-control after the worker boots so
#                         the user can drive it from their phone. Default: off
#                         (headless worker, monitored via tmux capture-pane).
#   Override the model with MODEL env var (default: sonnet):
#     MODEL=opus spawn-worker.sh my-app <slug> "<brief>"
#     MODEL=opus spawn-worker.sh --remote-control my-app <slug> "<brief>"
#
# Creates:
#   worktree: ~/repos/<repo>/<user>/<slug>/
#   branch:   <user>/<slug>
#   session:  worker-<repo>-<slug>
#
# <user> defaults to $USER; override with HARAMBE_USER_DIR env var.
#
# After the worktree is created, runs the optional overlay setup hook at
# $HARAMBE_ROOT/overlay/setup/<repo>.sh if one exists (e.g. copy personal
# config, install deps). See overlay.example/ for the pattern.
#
# The brief is written to <worktree>/.harambe-brief.md. Once Claude finishes
# booting, the worker is primed with a short message telling it to read that
# file, execute, and write WORKER_REPORT.md when done.
#
# Fails loudly if the session, branch, or worktree path already exists. Never
# overwrites.
#
# Model choice: Sonnet is the default and handles most tasks (applying specified
# plans, QA fix loops, routine coding, tests). Use MODEL=opus only when the
# worker needs genuine greenfield design, architectural thinking, or deep
# novel-bug diagnosis.
#
# Remote control: off by default. Turn on with --remote-control when the brief
# is structured around the user driving the worker from their phone (walkthroughs,
# QA loops with back-and-forth). Headless workers can still be switched into
# remote control on demand later with:
#   tmux send-keys -t <session> "/remote-control" Enter

set -euo pipefail

# -- parse args -------------------------------------------------------------

REMOTE_CONTROL=0
POSITIONAL=()

while [ $# -gt 0 ]; do
  case "$1" in
    --remote-control|-R)
      REMOTE_CONTROL=1
      shift
      ;;
    -h|--help)
      sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    --)
      shift
      POSITIONAL+=("$@")
      break
      ;;
    -*)
      echo "error: unknown flag '$1'" >&2
      exit 1
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done

set -- "${POSITIONAL[@]+"${POSITIONAL[@]}"}"

if [ $# -ne 3 ]; then
  echo "Usage: $0 [--remote-control] <repo> <slug> \"<brief>\"" >&2
  echo "Example: $0 my-app fix-login-spinner \"Fix the spinner flash on /login — see TICKET-1234.\"" >&2
  echo "With remote control: $0 --remote-control my-app qa-fixer \"Long QA loop — user drives from phone.\"" >&2
  exit 1
fi

REPO="$1"
SLUG="$2"
BRIEF="$3"
USER_DIR="${HARAMBE_USER_DIR:-$USER}"

MAIN_REPO="$HOME/repos/$REPO"
WORKTREE="$MAIN_REPO/$USER_DIR/$SLUG"
HARAMBE_ROOT="${HARAMBE_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
BRANCH="$USER_DIR/$SLUG"
SESSION="worker-$REPO-$SLUG"
BRIEF_FILE="$WORKTREE/.harambe-brief.md"
MODEL="${MODEL:-sonnet}"
CMD="claude --dangerously-skip-permissions --model $MODEL -n $SESSION"
BOOT_WAIT=10  # seconds before Claude accepts input (matches watchdog)
RC_WAIT=3     # extra seconds after priming before engaging remote control

# The message primed into the worker after it boots. Single-quoted so shell
# doesn't touch the contents — $vars, backticks, double quotes are all safe.
# The only character that would break this is a literal single quote; if you
# ever need to add "it's" or similar, either escape it with '\'' or switch
# to a co-located .txt file and `cat` it in.
#
# Headless workers (no remote control) get a terseness directive — they run
# long, nobody reads their output in real time, and every preamble paragraph
# is tokens spent for nothing. "Dense prose, no ceremony" beats caveman-speak
# because grep-ability and nuance still matter in reports.
PRIMING_PROMPT_BASE='Read .harambe-brief.md and execute it. When done, write WORKER_REPORT.md in this worktree root with: status (done/blocked/failed), one-line summary, changed files, any notes the user should see.'
PRIMING_TERSE=' You are a headless worker — nobody reads your output in real time. Write dense: no preambles, no restating the brief, no "I'\''ll now..." narration, no closing summaries of what you just did. Just the work and the result. Ping Harambe (via ~/repos/harambe/bin/harambe-say) only for blockers or handoff-worthy milestones, and keep pings to one sentence when one works. Same rule in WORKER_REPORT.md: terse, scannable, signal-dense.'
if [ "$REMOTE_CONTROL" -eq 1 ]; then
  PRIMING_PROMPT="$PRIMING_PROMPT_BASE"
else
  PRIMING_PROMPT="$PRIMING_PROMPT_BASE$PRIMING_TERSE"
fi

# -- sanity checks ----------------------------------------------------------

if [ ! -e "$MAIN_REPO/.git" ]; then
  echo "error: $MAIN_REPO doesn't look like a git repo. Is '$REPO' correct?" >&2
  exit 1
fi

if tmux has-session -t "$SESSION" 2>/dev/null; then
  echo "error: tmux session '$SESSION' already exists. Refusing to overwrite." >&2
  echo "       inspect: tmux attach -t $SESSION" >&2
  echo "       kill:    tmux kill-session -t $SESSION" >&2
  exit 1
fi

if [ -e "$WORKTREE" ]; then
  echo "error: worktree path already exists: $WORKTREE" >&2
  echo "       remove: git -C $MAIN_REPO worktree remove $WORKTREE" >&2
  exit 1
fi

if git -C "$MAIN_REPO" rev-parse --verify "refs/heads/$BRANCH" >/dev/null 2>&1; then
  echo "error: branch '$BRANCH' already exists. Refusing to reuse." >&2
  echo "       delete: git -C $MAIN_REPO branch -D $BRANCH" >&2
  exit 1
fi

# -- create worktree --------------------------------------------------------

echo "Creating worktree at $WORKTREE"
echo "  branch: $BRANCH"
echo "  model:  $MODEL"
if [ "$REMOTE_CONTROL" -eq 1 ]; then
  echo "  remote control: ON (will engage ${RC_WAIT}s after priming)"
fi
git -C "$MAIN_REPO" worktree add -b "$BRANCH" "$WORKTREE" >/dev/null

# -- run overlay setup hook if one exists -----------------------------------

# Per-repo setup lives in your personal overlay (gitignored):
#   $HARAMBE_ROOT/overlay/setup/<repo>.sh
# Runs with CWD = the new worktree, plus HARAMBE_REPO + HARAMBE_WORKTREE env.
HOOK="$HARAMBE_ROOT/overlay/setup/$REPO.sh"
if [ -x "$HOOK" ]; then
  echo "Running overlay hook: $HOOK"
  ( cd "$WORKTREE" && HARAMBE_REPO="$REPO" HARAMBE_WORKTREE="$WORKTREE" "$HOOK" ) || \
    echo "  (hook exited non-zero; continuing anyway)"
fi

# -- write brief to a file --------------------------------------------------

# Writing to a file (rather than stuffing the brief through send-keys) side-
# steps every shell-quoting landmine: newlines, backticks, $vars, quotes, the
# lot. The worker just reads the file.
printf '%s\n' "$BRIEF" > "$BRIEF_FILE"

# -- start tmux session -----------------------------------------------------

tmux new-session -d -s "$SESSION" -c "$WORKTREE" "$CMD"

# -- prime the worker (backgrounded so this script returns fast) ------------

(
  sleep "$BOOT_WAIT"
  tmux send-keys -t "$SESSION" "$PRIMING_PROMPT" Enter
  if [ "$REMOTE_CONTROL" -eq 1 ]; then
    sleep "$RC_WAIT"
    tmux send-keys -t "$SESSION" "/remote-control" Enter
  fi
) >/dev/null 2>&1 &
disown 2>/dev/null || true

cat <<EOF
Worker spawned.
  session:  $SESSION
  worktree: $WORKTREE
  branch:   $BRANCH
  model:    $MODEL
  remote control: $([ "$REMOTE_CONTROL" -eq 1 ] && echo "ON" || echo "off")

Priming in ${BOOT_WAIT}s. Track with:
  ~/repos/harambe/scripts/worker-status.sh
  tmux attach -t $SESSION    (detach: Ctrl-b d)

When done, read:
  $WORKTREE/WORKER_REPORT.md
EOF
