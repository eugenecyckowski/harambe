---
name: linear-triage
description: Proactive check — Linear issues assigned to the user that are waiting to be picked up. Surfaces newly-assigned items and ones sitting untouched for a while. Quiet when nothing has changed. Intended for heartbeat "proactive checks" but also runs on demand when the user asks about their Linear plate.
---

# Linear Triage

Tells the user what's sitting in Linear assigned to them that they haven't started on. Runs as part of the heartbeat's proactive checks, or on demand.

## When to run

- **On heartbeat** if `handoff.md` has a standing instruction containing `proactive checks` or explicitly naming `linear-triage`.
- **On demand** when the user asks things like "what's on my plate in Linear", "what Linear issues am I ignoring", "linear triage".

## Steps

### 1. Resolve the current user
Use the Linear MCP to identify the viewer (yourself → the user's Linear account). The relevant tool is typically `mcp__plugin_wealthbox_linear__get_user` with a self/viewer query, or look it up once and cache the user ID in state.

### 2. List open assigned issues — all teams
Use `mcp__plugin_wealthbox_linear__list_issues` with filters:
- `assignee.id` = current user
- `state.type` ∉ { `completed`, `canceled` }
- `state.name` ∉ { `Backlog` } (work not yet pulled in)
- Scope: no team filter — all teams where the user is assigned

Raise the page size / paginate if the default misses items. Fetch at least: id (e.g. `AIE-1913`), title, state, assignedAt (or updatedAt), url.

### 3. Diff against state

State file: `$HARAMBE_ROOT/state/linear-triage.json`

```json
{
  "last_run_at": "<ISO-8601 UTC>",
  "user_id": "<linear user id>",
  "seen": {
    "AIE-1913": { "first_seen": "<ISO>", "title": "...", "state": "Triage" }
  }
}
```

Categorize each fresh issue:
- **New** — in fresh list, not in `seen`.
- **Stale** — in `seen`, assigned >7 days ago, still open and not picked up.
- **Resolved** — in `seen`, not in fresh list. Drop from state silently.

### 4. Surface findings

If there's anything worth surfacing, append under `## Recent proactive findings` in `$HARAMBE_ROOT/handoff.md` (create the section if missing). Use a `[linear]` tag so the line is distinguishable from other proactive skills' output.

Format:
```
- [linear] 2 new assigned: AIE-1913 "Something short", AIE-1917 "Another thing"
- [linear] stale — AIE-1845 assigned 9d ago, untouched
```

If there's nothing new or stale: remove any existing `[linear]` lines from that section (clean sweep) and stay silent. Don't leave old findings lingering.

### 5. Write state
Update `$HARAMBE_ROOT/state/linear-triage.json` with the current fresh list merged into `seen`. Bump `last_run_at`.

## Rules

- **Read-only.** Never change issue status, assignee, or anything in Linear.
- **Quiet when idle.** If nothing changed, no lines under findings.
- **Graceful on failure.** If the Linear MCP is unauthenticated, rate-limited, or timing out: log one line to `state/heartbeat.log` ("linear-triage: skipped — <reason>") and move on. Don't block the heartbeat.
- **Bounded output.** Cap surface to top 5 new/stale items per category. If more, append "(and N more)".
