---
name: pr-watch
description: Proactive check — status changes on the user's open pull requests across all repos. Flags new review comments, new approvals, new requested-changes, merge conflicts, red CI. Silent when nothing has changed since the last tick. Intended for heartbeat proactive checks but runs on demand too.
---

# PR Watch

Watches the user's open PRs and surfaces what's changed since the last tick.

## When to run

- **On heartbeat** if `handoff.md` has a standing instruction containing `proactive checks` or explicitly naming `pr-watch`.
- **On demand** when the user asks things like "what's happening with my PRs", "any PR updates", "pr watch".

## Steps

### 1. List the user's open PRs — all repos

Use `gh search prs` (cross-repo, cross-org) with both `--author=@me` AND `--assignee=@me` and merge the results (dedupe by `repository.nameWithOwner#number`). A PR the user is assigned-but-didn't-author is still their problem to watch.

```bash
gh search prs --state=open --author=@me --limit 100 \
  --json number,title,url,repository,updatedAt,author

gh search prs --state=open --assignee=@me --limit 100 \
  --json number,title,url,repository,updatedAt,author
```

For each PR in the merged set, fetch full detail with `gh pr view <num> --repo <org/repo> --json ...` to get `mergeable`, `reviewDecision`, `latestReviews`, `statusCheckRollup`, `comments`. Do NOT use `gh pr list` — it's cwd/repo-scoped and silently returns nothing when run outside a repo.

### 2. Diff against state

State file: `$HARAMBE_ROOT/state/pr-watch.json`

```json
{
  "last_run_at": "<ISO>",
  "prs": {
    "starburstlabs/crm-web#19768": {
      "updated_at": "<ISO>",
      "review_decision": "APPROVED",
      "reviewer_approvals": ["jamesbyers"],
      "reviewer_changes_requested": [],
      "comment_count": 12,
      "mergeable": "MERGEABLE",
      "ci": "SUCCESS"
    }
  }
}
```

For each open PR, diff fresh vs stored:

- **New approval** — a reviewer now in `latestReviews[].state == APPROVED` who wasn't before.
- **New changes requested** — a reviewer now `CHANGES_REQUESTED` who wasn't before.
- **New comment** — `comments` count higher than stored, or `updatedAt` advanced.
- **Merge conflict (rebase needed)** — `mergeable` transitioned `MERGEABLE → CONFLICTING`.
- **CI failing** — `statusCheckRollup` transitioned to `FAILURE` (or `FAILING` checks present now, weren't before).

New PRs (not yet in state) don't generate noise — we just start tracking them. The first tick they appear on is their baseline.

### 3. Surface findings

Append under `## Recent proactive findings` in `$HARAMBE_ROOT/handoff.md`. Use a `[pr]` tag.

Examples:
```
- [pr] crm-web#19768 approved by @jamesbyers
- [pr] crm-web#19773 changes requested by @jk
- [pr] crm-web#19810 new comment (2 total since last check)
- [pr] wealthbox-mobile#87 merge conflict — rebase needed
- [pr] crm-web#19890 CI failing
```

If multiple PRs have changes, emit one line per PR/event. Group thematically if it helps readability. Cap at 10 lines total per tick; if more, append "(and N more on gh pr list)".

If nothing changed: remove any existing `[pr]` lines and stay silent.

### 4. Write state

Update `$HARAMBE_ROOT/state/pr-watch.json` with fresh state for each currently-open PR. Drop entries for PRs that closed/merged since last tick (silently — their event was already surfaced when it happened, if it was while we were watching).

## Rules

- **Read-only.** No replies, no reviews submitted, no merges.
- **Silent when idle.**
- **Graceful on failure.** If `gh` is unauthenticated / rate-limited / network error: log one line ("pr-watch: skipped — <reason>") and move on.
- **Per-repo scope is "all":** `--author @me` does the heavy lifting. If the user wants to scope down later, add a `HARAMBE_PR_WATCH_REPOS` env var with a comma-separated list and filter post-hoc.
