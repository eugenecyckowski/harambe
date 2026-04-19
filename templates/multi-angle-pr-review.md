# multi-angle PR review — reusable Agent prompt template

Snippet to drop into `Agent` calls when dispatching parallel review agents that each post their own batched inline review to a GitHub PR. Prefer a broad-coverage review skill (like a plugin's `deep-code-review`) when you want many personas; reach for this template only when you want a narrow set of angles (2–3) and full control.

Each agent posts ONE review via `POST /repos/OWNER/REPO/pulls/NUMBER/reviews` with batched inline comments. Event is always `COMMENT` — not REQUEST_CHANGES, not APPROVE. Comments are prefixed with a bracketed angle tag so the user can filter.

## Substitution variables
- `{{ANGLE}}` — e.g. Reliability, Security, Architecture, Performance, UX
- `{{PR_NUMBER}}` — e.g. 123
- `{{REPO}}` — e.g. org/repo
- `{{BRANCH}}` — e.g. user/feature-branch
- `{{WORKTREE}}` — absolute path if a local worktree exists; otherwise "no local worktree — read files from PR"
- `{{FEATURE_SUMMARY}}` — 1–2 sentences on what the PR does
- `{{HUNT_LIST}}` — bulleted list of concerns specific to this angle
- `{{STAY_OUT_OF}}` — other angles being reviewed in parallel; tell the agent to not duplicate their territory

## Template

Thorough {{ANGLE}} review of PR #{{PR_NUMBER}} in {{REPO}} (branch: `{{BRANCH}}`) — {{FEATURE_SUMMARY}}

**Your angle: {{ANGLE}}.**

Things to hunt for (not exhaustive — follow your nose):
{{HUNT_LIST}}

**Goal: thorough, not pedantic.** If the {{ANGLE}} posture is solid, say so. Positive comments on patterns done well are welcome. Don't manufacture findings.

**Stay in your lane.** Other agents are covering: {{STAY_OUT_OF}}. Avoid duplicating their angle.

**Setup:**
1. `gh pr view {{PR_NUMBER}} --repo {{REPO}} --json number,title,body,headRefOid,headRefName,files,baseRefName`
2. `gh pr diff {{PR_NUMBER}} --repo {{REPO}}`
3. Files live at: {{WORKTREE}} — read them directly. Or fetch: `git fetch origin {{BRANCH}}`.

**Posting comments:**

Post ONE batched review via the GitHub API. Prefix every comment body with `**[{{ANGLE}}]**`.

```bash
cat > /tmp/review-{{ANGLE_LOWER}}.json <<'EOF'
{
  "body": "{{ANGLE}} review of PR #{{PR_NUMBER}}. Overall summary — 1–2 paragraphs on the {{ANGLE}} posture.",
  "event": "COMMENT",
  "comments": [
    {"path": "...", "line": 42, "side": "RIGHT", "body": "**[{{ANGLE}}]** ..."},
    {"path": "...", "start_line": 10, "line": 15, "side": "RIGHT", "body": "**[{{ANGLE}}]** multi-line ..."}
  ]
}
EOF

gh api --method POST /repos/{{REPO}}/pulls/{{PR_NUMBER}}/reviews --input /tmp/review-{{ANGLE_LOWER}}.json
```

Rules:
- `event: "COMMENT"` — always. Not REQUEST_CHANGES, not APPROVE. This is thorough feedback, not a gate.
- `side: "RIGHT"` — for comments on new code (what you almost always want).
- `start_line` + `line` for multi-line, `line` alone for single-line.
- Keep comments specific and actionable (or specifically affirming). No filler.

**Acceptance:**
- Review posted successfully (gh api returns 200)
- No overlap with other angles — stay in your lane
- Overall summary reflects the real posture, not templated "consider adding X"

Return: URL of posted review + ~150-word summary of what you found. Under 250 words total.
