# Harambe's Brain

This is a structured knowledge vault. It persists across session resets and grows over time.

## Structure

| Folder | What goes here | Example |
|--------|---------------|---------|
| `inbox/` | Unsorted captures — triage within a week | Quick notes during a session |
| `people/` | People the user works with | Teammates, collaborators, stakeholders |
| `systems/` | Technical architecture docs | Service pipelines, integrations, subsystems |
| `learnings/` | Gotchas, patterns, things we keep rediscovering | "X silently fails when Y", recurring bugs |
| `decisions/` | Why we chose X over Y | Tool selection, architecture tradeoffs |
| `projects/` | Active project context and status | Whatever's in flight |
| `workflows/` | How the user does things, dev processes | QA flow, PR review process |
| `personal/` | Your profile, goals, preferences | Role, strengths, growth areas |
| `templates/` | Note templates for each type | learning.md, person.md, etc. |

## Conventions

- **Frontmatter on every note** — title, created, updated, author, tags, status
- **Tags are lowercase**, use hyphens for multi-word (`real-time`, not `realTime`)
- **Status**: `active`, `archived`, `draft`
- **Author**: `harambe` or the user's name
- **Filenames**: lowercase, hyphens, descriptive (`echo-cancellation-gotcha.md`)
- **Links**: Use `[[wikilink]]` style for cross-references between notes

## How Harambe uses this

### On session start
1. Read `handoff.md` (ephemeral session state)
2. If the handoff mentions a project/system, search the brain for related notes
3. Check `inbox/` for anything the user dropped in

### During work
- After discovering something worth remembering → write to `learnings/`
- After debugging sessions → document root cause and fix
- When exploring architecture → write or update `systems/`
- When meeting new people/collaborators → add to `people/`

### Before reset
- Capture session learnings → `learnings/` or `inbox/`
- Update any stale notes touched during the session
- Run `/brain-maintenance` if it's been a while

### Write-back rules
- Propose what to write and where — don't silently modify
- One note per concept — don't cram multiple learnings into one file
- Update existing notes rather than creating duplicates
- Quality over quantity — one good note beats ten sloppy ones
