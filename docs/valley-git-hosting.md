# Valley Git Hosting (classic-laddie)

classic-laddie serves bare git repositories via the `valley-host` NixOS module
from [gunk-dev/the-valley](https://github.com/gunk-dev/the-valley) (a public
repo, so fetching the flake input needs no token). This implements the infra half of
the-valley's outcome `oc-9949561` with the mechanism decided in
`dcr-db1acbb`: push-triggered git mirroring plus nightly restic backups.

## What is declared where

- `hosts/classic-laddie/valley.cue` — the domain declaration (projects,
  their push mirrors, which of their refs are protected and who may write
  them, and the backup policy — nightly restic, retention 7/4/6), validated
  at build time against the-valley's CUE schema. This is the only place
  projects are added.
- `hosts/classic-laddie/default.nix` — machine integration: enables
  `services.valley`, provisions the git user's SSH identity for mirror
  pushes, provisions the integrator's own signing identity, and supplies the
  backup's secret paths (`services.valley.backup.*`) with the enablement
  runbook alongside.
- The identity registry itself is a document in qinling's `identity/`
  directory, not a file here: `services.valley.identity.enable` compiles it
  at each pass into the signers whose evidence the integrator accepts and the
  git user's tagged `authorized_keys` (the-valley `dcr-b87f6e8`). It replaced
  the hand-written `hosts/classic-laddie/valley-known-signers`.

## Using it

```bash
# over the tailnet, as any key listed in secrets/keys.nix users
git clone git@classic-laddie:the-valley.git
```

Access is host-level and key-only: the `git` user runs `git-shell`, every
authorized key can reach every project. Repos live in `/srv/git` (moving to
a dedicated `tank/git` ZFS dataset is a follow-up).

### Who gets a key

`services.valley.authorizedKeys` is `keys.users ++ keys.gitOnly`, two classes
with deliberately different blast radius:

- **`users`** — Patrick's own machines. These are also agenix recipients
  (`secrets/secrets.nix` encrypts every secret to `users ++ hosts`) and shell
  users (`modules/common/users.nix`). A key here can read every secret in the
  repo.
- **`gitOnly`** — scratch boxes and agent VMs that need to clone and push
  projects and nothing else. Not agenix recipients, not shell users. Git
  hosting is their entire reach.

Add a machine that isn't yours to `gitOnly`. Because these keys are not
recipients, adding or removing one needs no secret re-encryption: edit
`keys.nix` and rebuild classic-laddie, and access changes with the
activation.

`users` keys are additionally tagged with the principal `patrick`; `gitOnly`
keys are untagged. Every push arrives as the shared `git` user, so the
principal is the only thing that distinguishes one pusher from another — and
an untagged key has no principal, so it can write nothing protected.

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

## Protected refs and the integrator (the-valley Phase 3)

Both projects protect `refs/heads/main`, with writers `patrick` and
`integrator`. A `pre-receive` hook enforces the one structural invariant:
only a declared writer may write a protected ref, and attestation refs
(`refs/the-valley/attestations/*`) are create-only for everyone. Everything
else — topic branches, tags — stays open.

Two writers is the transition arrangement, not the destination. Direct
pushes keep working while the integrator starts landing changes whose
evidence transfers; dropping `patrick` from the writers is what makes the
integrator the sole path onto main, and that happens once integration has
carried real work.

`services.valley.integrator` renders one `valley-integrator@<project>`
controller per protected project, running as `valley-integrator` (its own
unix identity, whose whole permission model is the git group). Each reads its
floor from qinling's integrated tip (`instanceProject = "qinling"`), and signs
its transfer statements under the `integrator` principal the registry
publishes its key as.

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
