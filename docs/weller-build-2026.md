# weller Build & Install Runbook (2026 Rebuild)

The X570/5950X `weller` died when its motherboard fried. The GPU and both NVMe
drives survived and return in this build. This document is the hardware record
and the install runbook for the new machine. It supersedes
[weller-dualboot-2025.md](./weller-dualboot-2025.md), which describes the old
board and remains useful only as history.

## 1. Hostname Scheme

Unchanged — one machine, three names depending on what is running:

| Environment | Hostname | Purpose |
|-------------|----------|---------|
| Windows 11 | `makers-mark` | Windows-only games (iRacing, BF6) |
| WSL2 NixOS | `makers-nix` | WSL environment inside `makers-mark` |
| Native NixOS | `weller` | Daily driver, development, Linux gaming |

## 2. Hardware

| Component | Details | Notes |
|-----------|---------|-------|
| **Motherboard** | MSI MAG X870E Tomahawk WiFi (AM5) | WiFi 7 + 5GbE, both in-tree |
| **CPU** | AMD Ryzen 9 9950X3D (16-core) | has an RDNA2 iGPU |
| **Cooler** | Arctic Liquid Freezer III Pro 420 AIO | no software support needed |
| **RAM** | G.Skill Trident Z5 Neo DDR5 (EXPO) | enable EXPO in BIOS |
| **GPU** | NVIDIA RTX 4090 | carried over; vertical mount on a PCIe 5.0 riser, card runs Gen4 |
| **Case** | HAVN HS 420 VGPU | |
| **PSU** | Corsair RM1200x | |
| **Disk 0** | Samsung 970 NVMe (932GB) | Windows — `makers-mark`. NixOS never touches it |
| **Disk 1** | Seagate FireCuda 510 NVMe (1.86TB) | NixOS — `weller`. Same physical drive as the old build, wiped |

Carried over from the old build, and still true:

- The FireCuda 510's firmware crashes under NVMe APST, so
  `nvme_core.default_ps_max_latency_us=0` stays on the kernel command line
  (#263).
- WiFi (MediaTek MT7925) and 5GbE (Realtek RTL8126) are handled by in-tree
  drivers on the kernel this flake tracks. Their firmware comes from
  `hardware.enableRedistributableFirmware`, which is already on. No extra
  modules or firmware packages are needed.

## 3. Disk Layout

Each OS owns a drive, each drive owns its ESP. There is no chainloading and no
shared boot partition — switch OSes from the BIOS boot menu (F11).

```
Disk 0 (Samsung 970 - 932GB):        [NixOS never touches this disk]
├── EFI System Partition             - Windows Boot Manager
├── Microsoft Reserved
├── Windows C:
└── Recovery partitions

Disk 1 (Seagate FireCuda - 1.86TB):  [hosts/weller/disk-config.nix]
├── EFI System Partition (1GB)       - systemd-boot
├── swap (32GB)                      - plain partition, unencrypted
└── zpool "wpool" (rest)             - ashift=12, autotrim, zstd, atime=off
    ├── wpool/root  (/)
    ├── wpool/nix   (/nix)     - reproducible, not snapshotted
    └── wpool/home  (/home)    - the dataset that gets snapshotted/sent
```

**No disk encryption.** Neither LUKS nor ZFS native encryption. The machine
boots unattended for Sunshine streaming and there is no passphrase prompt
anywhere in the boot path.

Swap is a real partition rather than a zvol: swapping onto a zvol deadlocks
under memory pressure, since ARC reclaim needs allocations to page out. There
is no hibernation requirement, so it is not a resume device.

The pool is `wpool`, deliberately unlike classic-laddie's `rpool`/`tank`, so
this disk can be imported on that host for rescue without a name collision.

> **Rule: the FireCuda comes OUT before any Windows repair or reinstall.**
> Windows installs its bootloader onto whichever ESP it finds first and will
> happily plant it on the NixOS drive, which then dies with the next `disko`
> run or leaves an orphan boot entry. Physically unplug Disk 1 (or disable its
> M.2 slot in BIOS), do the Windows work, then plug it back in.

## 4. BIOS Prep

Before installing anything:

1. **EXPO** — on. Trident Z5 Neo runs at JEDEC speeds otherwise.
2. **Resizable BAR** — on. Wanted by the 4090.
3. **Boot order** — put the FireCuda first once NixOS is installed; use **F11**
   for the one-shot boot menu to reach Windows or the installer.
4. **Secure Boot** — off. systemd-boot here is unsigned.
5. Note the BIOS version. MSI does not publish consumer boards to LVFS, so
   `fwupd` will not see the board firmware; BIOS updates are M-Flash from a
   FAT32 USB stick.

## 5. Installation (Two-Stage)

Two stages, to avoid the chicken-and-egg between agenix secrets and a host key
that does not exist until the machine boots.

> This two-stage flow is the **legacy** path, kept as the record of how weller
> was installed. New installs generate the host key onto the target disk before
> `nixos-install` and skip the bootstrap stage entirely — see
> [new-machine-playbook.md](./new-machine-playbook.md).

### 5.1 Stage 1: Bootstrap Install

`weller-bootstrap` is a minimal system: mutable users, SSH with the keys from
`secrets/keys.nix` pre-authorized, and no agenix (so nothing tries to decrypt
secrets the host cannot yet read).

1. **Boot the NixOS installer** — PXE via netboot.xyz (see
   [laddie-build-2025.md](./laddie-build-2025.md) for the UDM Pro setup) or a
   USB installer. F11 → the boot entry you want.

2. **Set the installer's hostid to weller's, before creating the pool.** This
   step is not optional — skipping it is what makes the first boot fail (§8).

   ```bash
   zgenhostid -f 74182f4c
   ```

   ZFS stamps the pool with the hostid of the machine that last imported it,
   and refuses an import from a *different* hostid unless the pool was cleanly
   exported. The installer has its own hostid; weller's committed one is
   `74182f4c` (`hosts/weller/hardware.nix`). Without this, `disko` creates the
   pool under the installer's hostid and the installed system — which boots as
   `74182f4c` with `boot.zfs.forceImportRoot = false` — treats `wpool` as a
   foreign pool. `zgenhostid` is part of the ZFS userland already on the
   installer; `-f` overwrites an existing `/etc/hostid`.

   Confirm it took before going any further — after `disko` runs, the pool is
   already stamped:

   ```bash
   hostid   # must print 74182f4c
   ```

3. **Partition and mount with disko** (no passphrase — nothing is
   encrypted):

   ```bash
   nix-shell -p git
   git clone https://github.com/patflynn/cosmo /tmp/cosmo
   cd /tmp/cosmo

   sudo nix --experimental-features "nix-command flakes" \
     run github:nix-community/disko -- \
     --mode disko ./hosts/weller/disk-config.nix
   ```

   The device is pinned by `by-id`
   (`nvme-Seagate_FireCuda_510_SSD_ZP2000GM30001_7QE00F0P`). Confirm it matches
   with `ls -la /dev/disk/by-id/ | grep -i seagate` before running — this wipes
   the disk.

4. **Install the bootstrap system**:

   ```bash
   nixos-install --no-write-lock-file --flake /tmp/cosmo#weller-bootstrap
   ```

5. **Export the pool before rebooting.** Belt and braces on top of step 2:

   ```bash
   umount -R /mnt && zpool export wpool
   ```

   `disko --mode disko` leaves the pool imported and `nixos-install` does not
   export it, so on reboot ZFS still sees it as *potentially active on another
   host* and refuses the import. A cleanly exported pool imports on any hostid,
   which makes this the step that saves the install even if step 2 was missed.

6. **Reboot** — it comes straight up, no prompt — then log in over SSH with a
   key from `secrets/keys.nix`:

   ```bash
   ssh root@weller
   ```

### 5.2 Stage 2: Host Key, Rekey, Full Config

1. **Read the new host key** (on weller):

   ```bash
   cat /etc/ssh/ssh_host_ed25519_key.pub
   ```

2. **Update secrets** (on a machine with a human age key — this cannot be done
   by an agent):

   - Replace the `weller` entry in `secrets/keys.nix` with the new host key.
     The entry there now is the **old** weller's key and is dead; there is also
     a stale user key commented `# weller` in the `users` list from the old
     install. Add the new key first, rekey, verify weller can decrypt, then
     remove the stale ones and rekey again.
   - `cd secrets && agenix --rekey`
   - Commit and push.

3. **Apply the full configuration** (on weller):

   ```bash
   cd ~/hack/cosmo   # clone it if this is the first time
   git pull
   sudo nixos-rebuild switch --flake .#weller
   ```

   This brings up the workstation profile: NVIDIA, Hyprland, Steam/gamescope,
   Sunshine auto-login, tailscale, hardened OpenSSH, immutable users.

## 6. Post-Installation

### 6.1 Tailscale

```bash
sudo tailscale up
```

### 6.2 Restore Data

Backups are now `zfs snapshot` + `zfs send` of `wpool/home` to
classic-laddie's `tank/personal`, replacing the old rsync of the same tree.

The pre-rebuild backup still lives there as a plain directory:

```bash
rsync -avhP classic-laddie:/tank/personal/weller-backup/ ~/restored-backup/
```

### 6.3 Bluetooth Keyboard

Nothing is typed before the desktop now, so the Kinesis just pairs normally
once booted.

### 6.4 Verify Dual-Boot

1. Reboot — NixOS should come up via systemd-boot on the FireCuda.
2. F11 → Windows Boot Manager on the Samsung; confirm Windows boots.
3. Set the preferred default in BIOS boot order.

### 6.5 Two GPUs

The 9950X3D's iGPU is live alongside the 4090. `amdgpu` is in the initrd so the
early console still renders if it lands on the iGPU — the fallback path if the
card is pulled. If the desktop ever comes up on the wrong adapter, pin the compositor with `WLR_DRM_DEVICES` rather than
disabling the iGPU in BIOS — the iGPU is a useful fallback if the 4090 needs to
come out.

## 7. Configuration Map

| File | Contents |
|------|----------|
| `hosts/weller/hardware.nix` | Bootloader, initrd, NVIDIA, filesystems, networking |
| `hosts/weller/disk-config.nix` | disko: ESP + swap partition + `wpool` ZFS datasets |
| `hosts/weller/default.nix` | Profile: users, desktop, gaming, tailscale, sshd, `stateVersion` |
| `flake.nix` | `weller` and `weller-bootstrap` targets |
| `secrets/keys.nix` | Host key — added by hand after first boot (§5.2) |

## 8. Troubleshooting

**Can't boot Windows after the NixOS install.** F11 → Windows Boot Manager, or
change boot order in BIOS. If the entry is gone entirely, Windows' ESP was
overwritten — that only happens if the drive-isolation rule in §3 was broken.

**Can't boot NixOS.** F11 → the Seagate drive. If systemd-boot loads but no
generation boots, pick the `stable` specialisation entry: it disables `scx`.
Note that the zen kernel is *already* overridden away on this host (see below),
so that entry differs only in `scx`.

**The kernel is not zen even though gaming is on.** Deliberate. ZFS upstream
caps at kernel 6.19 and linux-zen is past 7.0, so `hosts/weller/hardware.nix`
pins `pkgs.linuxPackages` with `lib.mkOverride 60`. Undo it and the system
stops building. sched-ext has been upstream since 6.12, so `services.scx` is
unaffected.

**Boot stops at "cannot import 'wpool': pool was previously in use from
another system".** §5.1 step 2 (`zgenhostid -f 74182f4c`) or step 5
(`zpool export wpool`) was skipped, so the pool is stamped with the installer's
hostid and still marked active. `boot.zfs.forceImportRoot = false` means the
initrd imports without `-f`, so it stops rather than stealing the pool.

To get in once, add `zfs_force=1` to the kernel command line from the
systemd-boot entry editor (**e**). Then, once booted, export and re-import
cleanly so the pool is stamped with weller's hostid — from the installer, since
the root pool cannot be exported while it is mounted:

```bash
zpool import -f wpool && zpool export wpool
```

A later `networking.hostId` change produces the same error for the same reason;
the fix is to put the committed value back, not to force the import.

If instead the initrd never sees the disk at all, that is a missing `nvme`
module or a wrong `by-id` path in `disk-config.nix` — different symptom, same
blank console.
