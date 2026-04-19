# Personal overlay

This directory (committed as `overlay.example/`) shows the shape of your **personal overlay** — the place for setup logic and other per-repo details that shouldn't ship in a shared Harambe repo.

## How it works

Copy this directory to `overlay/` (not `overlay.example/`) in your Harambe root:

```bash
cp -r overlay.example overlay
```

`overlay/` is gitignored. Nothing you put there gets committed.

## Setup hooks

When `scripts/spawn-worker.sh` or `scripts/checkout-worktree.sh` creates a new worktree, they check for:

```
$HARAMBE_ROOT/overlay/setup/<repo>.sh
```

If the file exists and is executable, it runs with:
- **CWD** = the newly-created worktree
- **`$HARAMBE_REPO`** = the repo name (e.g. `my-app`)
- **`$HARAMBE_WORKTREE`** = the absolute worktree path

Use it for anything you'd normally do manually after cloning:
- Copy a personal `CLAUDE.local.md` into the worktree
- `yarn install` / `bundle install` / `pnpm i`
- Symlink `node_modules` from the main repo (saves disk)
- Copy `.env.local`
- Warm any caches

See `setup/_example.sh` for a working template.

## Other overlay content

Nothing stops you from putting additional personal bits in `overlay/` — notes, helper scripts, templates. The `overlay/` directory is yours. Only `overlay/setup/<repo>.sh` is called automatically; the rest is whatever you want it to be.
