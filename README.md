# Harambe

An always-on personal assistant for engineers who want a coding agent that stays awake and coordinates other coding agents. Harambe is a single Claude Code session running in a tmux pane, kept alive by a watchdog, checking in on a heartbeat, and reachable from your phone via the Claude Code mobile app.

Lightweight by design. No daemons, no HTTP, no MCP server of its own — just bash, tmux, launchd, and a few conventions.

> **Personal pet project.** Shared as a pattern to learn from or fork, not as a maintained product. No support, no roadmap, no promises. Feel free to take what's useful.

## What it is

Three small primitives glued together:

- **Heartbeat** — a launchd timer fires on an interval (default every 5 minutes) and sends the literal word `heartbeat` into Harambe's tmux pane. Harambe reads its `handoff.md`, executes "Standing instructions", logs the tick, and resets itself for a fresh context.
- **Inbox** — worker agents ping Harambe by running `harambe-say "message"`. The script writes a timestamped markdown file to `inbox/` and sends the word `inbox` into Harambe's pane, rate-limited so bursts of worker pings don't interrupt a live conversation.
- **Worker spawn** — `scripts/spawn-worker.sh <repo> <slug> "<brief>"` creates a new branch, worktree, and tmux session running its own Claude. Workers live in their own OS process, survive Harambe's resets, and show up in the Claude Code mobile app.

On top of that sits a three-tier memory model:

- **Brain** (`brain/`) — curated, permanent knowledge. People, systems, learnings, decisions. Git-backed.
- **Memory** (`~/.claude/projects/.../memory/`) — behavioral preferences that auto-load into every conversation.
- **Handoff** (`handoff.md`) — ephemeral session state, overwritten each reset.

That's the whole system.

## Requirements

- macOS (launchd — Linux port would need systemd user units, not done yet)
- tmux
- Claude Code CLI (with `claude` on PATH)
- git
- bash

## Install

```bash
# 1. Clone somewhere stable
git clone https://github.com/eugenecyckowski/harambe.git ~/repos/harambe
cd ~/repos/harambe

# 2. Create your personal overlay — voice, workspace, preferred skills
cp CLAUDE.local.md.example CLAUDE.local.md
$EDITOR CLAUDE.local.md

# 3. (Optional) set up per-repo overlay hooks for worktree setup
cp -r overlay.example overlay
# then add overlay/setup/<repo>.sh scripts as needed

# 4. Start from a template handoff
cp templates/handoff.md.example handoff.md

# 5. Install the launchd plists (watchdog keeps the tmux pane alive,
#    heartbeat fires the interval timer).
bin/harambe install-launchd
bin/harambe install-heartbeat

# 6. Start the session.
bin/harambe start
```

Optional: `alias h='~/repos/harambe/bin/harambe'` in your shell rc.

## Daily use

```bash
harambe status          # what's running, last heartbeats
harambe attach          # attach to the tmux pane
harambe reset           # fresh context, ~15s
harambe pause           # pause autonomous heartbeat ticks
harambe resume
harambe heartbeat       # fire a tick manually
harambe interval 5m     # change heartbeat interval
```

## Extending

- **Behavior** — edit `CLAUDE.md` (the primitive contract) or `CLAUDE.local.md` (your overlay).
- **Brain conventions** — see `brain/CLAUDE.md`.
- **Skills** — Claude Code plugins cascade; drop skill files into `~/.claude/skills/` or `.claude/skills/` inside this repo.
- **Worker patterns** — `scripts/spawn-worker.sh --help` and `scripts/checkout-worktree.sh --help`.

## What's user-configurable

- `HARAMBE_ROOT` — override the default install path (`$(cd $(dirname $0)/.. && pwd)`).
- `HARAMBE_USER_DIR` — branch-prefix and worktree-layout username. Defaults to `$USER`.
- `HARAMBE_SESSION` — tmux session name (default `harambe`). Workers read this to know where to send `inbox` triggers.
- `HARAMBE_PING_RATE_LIMIT_SECS` — `harambe-say` trigger rate-limit window (default 300).

## License

MIT. See [LICENSE](LICENSE). Not a product, just a pattern you can fork.
