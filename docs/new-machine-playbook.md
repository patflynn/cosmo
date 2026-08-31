# New Machine Playbook

Bringing any new physical NixOS host into cosmo, from an unboxed machine to a
fleet member that decrypts its own secrets. Machine-agnostic; substitute your
own `<host>`, pool name and hostId throughout.

[weller-build-2026.md](./weller-build-2026.md) is the worked example — read it
alongside this for concrete values (disk layout, `by-id` paths, board quirks).

## The shape of the install

Give the machine its host key **before** it is installed, not after it boots:

1. Declare the host in this repo and merge it.
2. Boot the installer, set the ZFS hostid, run `disko`.
3. Generate the host key onto the mounted target disk, publish the public half,
   rekey agenix, merge.
4. `nixos-install` the **full** target — one install, one reboot, done.

This works because `nixos-install` never writes `/etc/ssh/ssh_host_*`, and sshd
only generates a host key when none exists — so a key placed at
`/mnt/etc/ssh/ssh_host_ed25519_key` is the key the installed system boots with,
and agenix can decrypt on the very first boot. The private half never leaves the
disk it will live on.

Consequence: the two-stage bootstrap path (`mkBootstrap` in `flake.nix`,
`modules/bootstrap.nix`) is **legacy**. It exists for hosts installed before this
playbook and is not needed for a new install.

## 1. Declare the host first

Nothing is installed until the flake can build the target. Create:

- `hosts/<host>/default.nix` — profile: users, desktop/server role, tailscale,
  sshd, `system.stateVersion`.
- `hosts/<host>/hardware.nix` — bootloader, initrd modules, filesystems,
  `networking.hostId`.
- `hosts/<host>/disk-config.nix` — disko layout.

Wire it into `flake.nix` `nixosConfigurations` (add `disko.nixosModules.disko`
and `agenix.nixosModules.default` to the module list), and update the
`# Managed hosts:` comment at the top of `flake.nix`.

**Pick and commit `networking.hostId` now** if the host uses ZFS. Eight hex
digits:

```bash
head -c4 /dev/urandom | od -A none -t x4 | tr -d ' '
```

It must never change afterwards: ZFS stamps the pool with the hostid of the
machine that last imported it and, with `boot.zfs.forceImportRoot = false`,
refuses to import a pool last held by a different hostid.

Pin the disko `device` to a stable `/dev/disk/by-id/` path, never `/dev/nvme0n1`
— kernel enumeration order is not stable and `disko` wipes what it is pointed at.

Worked example: `hosts/weller/{default,hardware,disk-config}.nix`.

## 2. Firmware prep

Do this before the machine is on the network for real:

1. **Enable the UEFI network stack** (MSI: *Settings → Advanced → Network Stack*;
   IPv4 PXE on). Without it there is no PXE entry in the boot menu.
2. **Disable Fast Boot.** Fast Boot skips USB controller init, so the keyboard is
   dead while the "press DEL" prompt is on screen — DEL is simply never seen.
3. **Wired keyboard, rear USB-A port.** Front-panel headers and hubs are often
   not initialised early enough; Bluetooth keyboards never are.
4. Secure Boot off (systemd-boot here is unsigned), plus whatever the board needs
   for its RAM and GPU (EXPO/XMP, Resizable BAR).

Locked out of the firmware because of #2? Escape hatches, no CMOS jumper needed:

```bash
systemctl reboot --firmware-setup      # any Linux — sets the OsIndications EFI var
```

```
shutdown /r /fw /t 0                   :: Windows, admin prompt
```

Clear-CMOS is the last resort; it also drops EXPO and boot order.

## 3. Boot the installer

PXE is the default path — classic-laddie already serves netboot.xyz and needs no
changes:

- `atftpd` on classic-laddie serves `/srv/tftp` (`hosts/classic-laddie/default.nix`).
- UDM Pro: *Settings → Networks → \<network\> → Network Boot* → server
  `192.168.1.28`, filename `netboot.xyz.efi`.
- F11 at POST → the IPv4 PXE entry.

**Choose the newest NixOS in netboot.xyz's list.** The installer kernel has to
drive the board's NIC: a 24.11 (6.6) installer has no driver for, e.g., the
RTL8126 5GbE on current AM5 boards and lands at a prompt with no network at all.
A USB stick written from a current minimal ISO is the fallback and is worth
having on hand anyway.

In the installer:

```bash
sudo -i                                # everything below is root
```

`nixos-install` accepts `--flake` as-is, but a bare `nix run` does not:

```bash
nix --experimental-features "nix-command flakes" run github:nix-community/disko -- ...
```

## 4. Set the ZFS hostid, before disko

Skip this and the pool is created under the *installer's* hostid, and the
installed system refuses to import its own root pool at boot ("pool was
previously in use from another system").

The live ISO's `/etc/hostid` is a symlink into the read-only store, so
`zgenhostid -f` alone fails with *read-only file system*. Remove it first:

```bash
rm -f /etc/hostid
zgenhostid -f <hostId>     # the value committed in hosts/<host>/hardware.nix
hostid                     # must print <hostId> — confirm BEFORE disko
```

After `disko` runs the pool is already stamped, so the confirmation is the whole
point of doing it here.

## 5. Disko → host key → rekey → install

```bash
nix-shell -p git
git clone https://github.com/patflynn/cosmo /tmp/cosmo
cd /tmp/cosmo

# Confirm the by-id path matches this machine's disk — this wipes it.
ls -la /dev/disk/by-id/

nix --experimental-features "nix-command flakes" \
  run github:nix-community/disko -- \
  --mode disko ./hosts/<host>/disk-config.nix
```

`disko` leaves the filesystems mounted at `/mnt`. Generate the host key onto the
target disk:

```bash
mkdir -p /mnt/etc/ssh
ssh-keygen -t ed25519 -N "" -f /mnt/etc/ssh/ssh_host_ed25519_key
cat /mnt/etc/ssh/ssh_host_ed25519_key.pub
```

Then, on a machine holding a human age key (an agent cannot do this):

- add the public key to `secrets/keys.nix` under `hosts`,
- `cd secrets && agenix --rekey`,
- commit, PR, merge.

See [secrets-management.md](./secrets-management.md). Every secret is encrypted
to `users ++ hosts` (`secrets/secrets.nix`), so the rekey is what lets the new
host read anything at all.

Back in the installer, pick up the merged rekey and install the full target:

```bash
git -C /tmp/cosmo pull
nixos-install --no-write-lock-file --flake /tmp/cosmo#<host>
```

Pass `--no-root-passwd` if it stops to ask for one: hosts here run
`users.mutableUsers = false` and take the account password from agenix
(`modules/common/users.nix`), so a root password set at install time is
overwritten by the first activation anyway.

Export the pool before rebooting — a cleanly exported pool imports under any
hostid, which rescues the install even if §4 was botched:

```bash
umount -R /mnt && zpool export <pool>
```

## 6. First boot

If the firmware boot list shows no entry for the new disk, it is usually
presentation, not a missing bootloader: MSI/AMI firmware collapses every EFI
disk into a single **UEFI Hard Disk** entry, and the choice of *which* disk lives
under *Hard Disk Drive BBS Priorities*. **F11** lists loaders individually and is
the fastest way to confirm the entry exists.

If it genuinely does not, boot the installer again and check the ESP:

```bash
mount /dev/disk/by-id/<disk>-part1 /mnt      # the ESP
ls /mnt/EFI                                  # expect: systemd, BOOT, nixos
efibootmgr -c -d /dev/disk/by-id/<disk> -p 1 \
  -L "Linux Boot Manager" -l '\EFI\systemd\systemd-bootx64.efi'
```

`EFI/systemd` present means the install worked and only the NVRAM entry is
missing — that is what `efibootmgr -c` writes back.

## 7. Join the fleet

```bash
sudo tailscale up
```

Then:

- Add the host to the host table in any README or doc that carries one, and to
  the `# Managed hosts:` line in `flake.nix`.
- **The owner's SSH key on the new machine** is a *user* key, not the host key:
  add it to the `patrick` list in `secrets/keys.nix` and rekey again. Same trip,
  **remove the dead keys** belonging to wiped or retired installs rather than
  leaving them as live recipients — a stale entry is a key that can still decrypt
  every secret.
- **Valley identity.** If the machine should push to or attest for valley
  projects, its key goes into qinling's `identity/registry.cue` — not into a file
  in this repo — through the integration path: a push-only grant for a machine
  that just clones and pushes, a `signs` grant only if it produces attestations.
  See [valley-git-hosting.md](./valley-git-hosting.md).

## 8. Where this goes next

The natural graduation is [nixos-anywhere](https://github.com/nix-community/nixos-anywhere),
which folds §4–§5 into one command from a workstation — disko, `--extra-files`
to plant the pre-generated host key, and the install, all over ssh — and which
this playbook is deliberately the manual form of until the fleet has a reason to
adopt it.
