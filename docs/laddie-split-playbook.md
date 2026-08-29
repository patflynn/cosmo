# laddie-split surgery playbook

Self-contained field copy for the hardware split — readable while classic-laddie is down.
Source of truth: `~/hack/laddie-split/` on classic-laddie (this doc is the 2026-08-28 snapshot).

## End state

| | classic-laddie (server) | weller / makers-mark (desktop) |
|---|---|---|
| Board | Gigabyte Aorus mini-ITX (current) | MSI MAG X870E Tomahawk WiFi |
| CPU | Ryzen 9 5950X | Ryzen 9 9950X3D |
| RAM | 32GB DDR4 (current sticks) | Trident Z5 Neo DDR5, slots **A2+B2** |
| Cooler | Noctua NH-U12A | Arctic LF III Pro 420 A-RGB, top mount |
| GPU | AORUS RTX 3080 Ti Master 12GB (from closet) | AORUS RTX 4090 (from the H710), vertical on riser |
| PSU | Corsair SF750 (SFX — bracket?) | Corsair RM1200x (from the H710) |
| Case | Lian Li white/wood (under stairs) | HAVN HS 420 VGPU black |
| Disks | WD SN850 1TB (`rpool`) + SanDisk 4TB SATA (`tank`) — move as-is | FireCuda 510 2TB in **M2_1** (weller, LUKS — salvage first!), Samsung 970 1TB in **M2_4** (makers-mark, Windows). **M2_2 stays empty** (shares lanes with USB4). |
| Boot | NixOS, same install — no reinstall | Dual-boot via BIOS boot order + F11 |

Build state so far: weller bench build has CPU, RAM, both NVMes, AIO brackets, board in
case; LF III going in top-mounted (tubes-front per Arctic; verify 65mm stack clears the
DIMMs before committing — side 420 mount is the fallback). Waiting on: Arctic P14 Pro
5-pack (3x duct + 2x rear). 4090/riser/RM1200x stay out until laddie teardown.

## Gates before laddie teardown

1. Server-diet PR (strips desktop config, 14B llama-swap roster for 12GB): review →
   merge → `sudo systemctl start cosmo-rebuild` → **one reboot** → verify → then shutdown.
   The converge loop deploys main within the hour of merge — merge means go.
2. Snapshots: `sudo zfs snapshot -r rpool@pre-split && sudo zfs snapshot -r tank@pre-split`
3. Restic restore drill (oc-9949561, never yet proven): commands in qinling
   `docs/migrate-and-restore.md`, `restic-valley` wrapper. Do before moving the SOT.
4. No klaus agents running; coordinator session dies with the box (state on disk).
5. **Know the old weller LUKS passphrase** — the salvage depends on it.

## Laddie: H710 → Lian Li

- Clean shutdown. Strip the H710 completely (it retires): 4090, RM1200x, ITX board+RAM,
  WD NVMe + 4TB SATA out. Kraken off the CPU — **stock AM4 backplate must stay on the
  board** (Noctua SecuFirm2 needs it). Graceless extraction is fine.
- Lian Li build: board in, NH-U12A on (NT-H1 in box; fans clear of DIMMs, can slide up),
  3080 Ti in, SF750 in (check SFX bracket), both drives connected.
- First boot at the desk, monitor on the 3080 Ti (same NVIDIA driver, no config change):
  - Boots the pre-diet or diet config depending on merge timing; converge fixes drift:
    `sudo systemctl start cosmo-rebuild` (or wait for the hourly timer).
  - Sanity: `zpool status -x` → both pools; `nvidia-smi` → 3080 Ti; `tailscale status`.
- Relocate under stairs: 2.5GbE into the switch/UDM (same MAC → same IP 192.168.1.28,
  PXE config unchanged), power, boot unattended.

### Service sweep (over SSH)

```
zpool status -x                       # pools healthy
systemctl --failed                    # expect none
ls /mnt/media /mnt/personal           # tank mounts
systemctl is-active plex jellyfin sonarr radarr prowlarr home-assistant \
  github-relay reel-life valley-bus valley-integrator@the-valley \
  valley-integrator@qinling llama-swap open-webui podman-gluetun
journalctl -u podman-gluetun -n 20    # wireguard up, healthcheck listening
curl -s -o /dev/null -w '%{http_code}\n' localhost:8123   # HA = 200
```

Plus: reel-life answers on Telegram; `git fetch` from a valley clone works;
llama-swap serves the new 14B roster (first pull per model is slow, ~9GB each).

## Weller: finish + install (when fans arrive)

- 3x P14 Pro in the VGPU angled duct, 2x rear exhaust (PST-chain each group).
  AIO all-in-one cable → CPU_FAN (curve floor ≥30%, pump shares the signal);
  ARGB → JRAINBOW. Riser plug → PCI_E1, ribbon clear of the lower M.2; 4090 into the
  bracket receptacle; 12VHPWR native cable from the RM1200x, gentle bend at the glass.
- BIOS (Flash Button update already done? if not: USB stick, PSU only): EXPO on,
  Resizable BAR on, F11 = boot menu. First DDR5 boot can train memory for 1-3 min on a
  blank screen — do not reset.
- Windows first: boot the 970 (makers-mark) — expect re-activation + MSI chipset
  drivers. Disable Fast Startup. If it needs repair/reinstall: **pull the FireCuda
  first** (one clip, M2_1) so Windows' EFI stays on its own disk.
- NixOS (classic-laddie must be back online for PXE; USB installer as backup):
  1. PXE boot → netboot.xyz → NixOS installer.
  2. **Salvage before disko**: `cryptsetup open /dev/disk/by-id/nvme-Seagate_FireCuda_510_*-part2 old`
     → mount, rsync anything wanted from the old `/home` to
     `classic-laddie:/mnt/personal/weller-backup/` — then close it.
  3. `sudo nix run github:nix-community/disko -- --mode disko ./hosts/weller/disk-config.nix`
     (prompts for the NEW LUKS passphrase; wipes the FireCuda).
  4. `nixos-install --no-write-lock-file --flake github:patflynn/cosmo#weller-bootstrap`
  5. Reboot → ssh in as root → add host key to `secrets/keys.nix`, `agenix -r`, push →
     `nixos-rebuild switch --flake .#weller` → `tailscale up`.
  Full flow: cosmo `docs/weller-build-2026.md`.
- Verify dual-boot both directions via BIOS order + F11. rsync wanted `$HOME` content
  from classic-laddie. Burn-in: EXPO stability, a long gaming session, vertical-GPU
  thermals.

## Aftercare (next sessions)

- Docs: refresh `classic-laddie-hardware.md` (3080 Ti becomes true again), memory
  updates (4090 → weller), sell/recycle H710 + Kraken.
- Watch crash-capture on laddie: does the silent-lockup history follow the ITX board?
- Valley attest from weller: registry `signs:` grant + env vars (tracked in runbook).
- Week-later: temps/dust under the stairs, UPS decision.
