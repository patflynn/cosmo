# Valley Git Hosting (classic-laddie)

classic-laddie serves bare git repositories via the `valley-host` NixOS module
from [gunk-dev/the-valley](https://github.com/gunk-dev/the-valley) (a private
repo — see "Private flake input" below). This implements the infra half of
the-valley's outcome `oc-9949561` with the mechanism decided in
`dcr-db1acbb`: push-triggered git mirroring plus nightly restic backups.

## What is declared where

- `hosts/classic-laddie/valley.cue` — the domain declaration (projects and
  their push mirrors), validated at build time against the-valley's CUE
  schema. This is the only place projects are added.
- `hosts/classic-laddie/default.nix` — machine integration: enables
  `services.valley`, provisions the git user's SSH identity for mirror
  pushes.
- `hosts/classic-laddie/valley-backup.nix` — nightly restic backup of the
  repo directory to a Hetzner Storage Box. **Disabled** until the Storage
  Box exists; the file's header comment is the enablement runbook.

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

## Private flake input

`github:gunk-dev/the-valley` is private, so every `nix` invocation that
fetches it needs a GitHub token:

- **CI / update-flake-lock** mint a read-only token from the
  `cosmo-automation` GitHub App — the app must be installed on `gunk-dev`
  with access to `the-valley`.
- **classic-laddie's `cosmo-rebuild`** reads the `github-token` agenix
  secret — that token must be able to read `gunk-dev/the-valley`.
- **Manually**: `nix ... --option access-tokens "github.com=$(gh auth token)"`.

## Offsite backups (pending)

Blocked on provisioning the Hetzner VPS (git mirror target) and Storage Box
(restic target) — see the-valley `dcr-db1acbb`. Once provisioned: follow the
runbook in `valley-backup.nix`, flip `cosmo.valley.backup.enable`, and add
the VPS mirror URL to `valley.cue`. The outcome closes only after a restore
is performed and verified.
