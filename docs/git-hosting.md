# Git Hosting (classic-laddie)

`classic-laddie` hosts bare git repositories as the canonical origin for
personal repos (source-hosting migration Phase 0). The reusable module lives
in `modules/git-hosting/` and is enabled in `hosts/classic-laddie/default.nix`.

Repos live on the ZFS pool at `/mnt/git` (dataset `tank/git`), owned by a
dedicated `git` user whose shell is `git-shell` — no interactive login, SSH
keys only. Access control is deliberately thin: Tailscale ACLs plus the SSH
keys in `secrets/keys.nix` (`users`) are the whole identity story.

## One-time host prep

The ZFS dataset is not created by the module. Before the first deploy that
enables the module:

```bash
sudo zfs create -o mountpoint=legacy tank/git
```

## Adding a repo

Add the name (no `.git` suffix) to the repo list in
`hosts/classic-laddie/default.nix`:

```nix
services.git-hosting.repos = [
  "the-valley"
  "new-repo"
];
```

On the next rebuild, `/mnt/git/new-repo.git` is created as an empty bare
repository (initial branch `main`). Existing repositories are never touched;
removing a name from the list leaves its data in place on disk.

## Cloning and pushing

Over the tailnet, SSH to the `git` user on `classic-laddie`:

```bash
git clone git@classic-laddie:the-valley.git
```

To point an existing checkout at the new origin:

```bash
git remote add origin git@classic-laddie:the-valley.git   # or `set-url`
git push -u origin main
```

Paths are relative to the git user's home (`/mnt/git`), so the bare
`name.git` form works. Any key in `secrets/keys.nix` `users` can push; to
grant access to a new machine, add its key there (and rekey — see
[secrets-management](./secrets-management.md)).

## Hooks

Each repo's `post-receive` is a managed dispatcher that runs every
executable in the repo's `post-receive.d/` directory, in order:

```
/mnt/git/<name>.git/hooks/post-receive      # managed symlink — do not edit
/mnt/git/<name>.git/hooks/post-receive.d/   # drop executable hooks here
```

Each hook receives the standard post-receive input (`<old> <new> <ref>`
lines) on stdin. This is the wiring point for the planned offsite
replication hook (Hetzner mirror, follow-up work). A hand-written
`post-receive` file is left alone by the module; only the managed symlink is
updated across rebuilds.
