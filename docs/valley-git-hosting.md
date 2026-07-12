# Valley Git Hosting (classic-laddie)

classic-laddie serves bare git repositories via the `valley-host` NixOS module
from [gunk-dev/the-valley](https://github.com/gunk-dev/the-valley) (a public
repo, so fetching the flake input needs no token). This implements the infra half of
the-valley's outcome `oc-9949561` with the mechanism decided in
`dcr-db1acbb`: push-triggered git mirroring plus nightly restic backups.

## What is declared where

- `hosts/classic-laddie/valley.cue` — the domain declaration (projects,
  their push mirrors, and the backup policy — nightly restic, retention
  7/4/6), validated at build time against the-valley's CUE schema. This is
  the only place projects are added.
- `hosts/classic-laddie/default.nix` — machine integration: enables
  `services.valley`, provisions the git user's SSH identity for mirror
  pushes, and supplies the backup's secret paths
  (`services.valley.backup.*`) with the enablement runbook alongside.

## Using it

```bash
# over the tailnet, as any key listed in secrets/keys.nix users
git clone git@classic-laddie:the-valley.git
```

Access is host-level and key-only: the `git` user runs `git-shell`, every
authorized key can reach every project. Repos live in `/srv/git` (moving to
a dedicated `tank/git` ZFS dataset is a follow-up).

Every push is replicated best-effort to each mirror URL declared in
`valley.cue` (`git push --mirror`, detached). A dead mirror only costs a
journal line: `journalctl -t valley-mirror`.

## Activating the GitHub mirror

Mirror pushes fail-log until the git user has a real identity:

1. `ssh-keygen -t ed25519 -N "" -C valley-mirror@classic-laddie -f valley-mirror`
2. `cd secrets && agenix -e valley-git-ssh-key.age` — paste the private key
   (the committed file is an encrypted placeholder).
3. Add the public key as a deploy key **with write access** on
   `github.com/gunk-dev/the-valley`.

## Offsite backups (pending)

The backup is declared in `valley.cue` (the `backup` block, the-valley's
`#Backup`), so the nightly restic unit already renders — it fail-logs
harmlessly until the Storage Box exists and the secrets are populated, same
as the mirror push. Once the Hetzner VPS (git mirror target) and Storage Box
(restic target) are provisioned — see the-valley `dcr-db1acbb` — follow the
runbook next to `services.valley.backup` in
`hosts/classic-laddie/default.nix`, and add the VPS mirror URL to
`valley.cue`. The outcome closes only after a restore is performed and
verified.
