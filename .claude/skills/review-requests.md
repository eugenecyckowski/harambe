---
name: review-requests
description: Proactive check — PRs where the user is requested as a reviewer and hasn't submitted a review yet. Surfaces only newly-arrived requests; quiet when nothing has changed. Intended for heartbeat proactive checks but runs on demand too.
---

# Review Requests

Tells the user which PRs are waiting on their review.

## When to run

- **On heartbeat** if `handoff.md` has a standing instruction containing `proactive checks` or explicitly naming `review-requests`.
- **On demand** when the user asks things like "what needs my review", "any review requests", "who's waiting on me".

## Steps

### 1. List review requests

```bash
gh search prs --review-requested=@me --state=open --limit 50 \
  --json number,title,url,repository,author,updatedAt,createdAt
```

`@me` resolves to the authenticated user across all orgs/repos they have access to. Already-reviewed requests (where the user has already left a review) are filtered out by `--review-requested=@me` when combined with GitHub's dismissal semantics — if not, filter them client-side with `gh api`.

### 2. Diff against state

State file: `$HARAMBE_ROOT/state/review-requests.json`

```json
{
  "last_run_at": "<ISO>",
  "seen": {
    "starburstlabs/crm-web#19810": {
      "first_seen": "<ISO>",
      "author": "jk",
      "title": "..."
    }
  }
}
```

Categorize each fresh request:
- **New** — not in `seen`.
- **Stale** — in `seen`, `first_seen` >3 days ago, still open and awaiting review.
- **Resolved** — in `seen`, not in fresh list. Drop silently.

### 3. Surface findings

Append under `## Recent proactive findings` in `$HARAMBE_ROOT/handoff.md`. Use a `[review]` tag.

Examples:
```
- [review] crm-web#19810 from @jk — "Feature X spike"
- [review] crm-web#19756 waiting 4d (stale) — from @jamesbyers
```

If nothing new or stale: remove any existing `[review]` lines and stay silent.

### 4. Write state

Update `$HARAMBE_ROOT/state/review-requests.json` with the fresh list merged into `seen`.

## Rules

- **Read-only.** Never submit a review, leave a comment, or dismiss a request.
- **Silent when idle.**
- **Graceful on failure.** `gh` unauthenticated / rate-limited / network error → log "review-requests: skipped — <reason>" and move on.
- **Cap output.** Top 5 new + top 3 stale. If more, append "(and N more)".
