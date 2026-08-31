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
  - **Third M.2:** there is an unlabelled 2280 NVMe in the underside (chipset) slot that
    cosmo has never documented — not in `rpool`, not in `tank`, no `nvme1` anywhere in
    the repo's history. It was well seated and the box ran fine with it, so it goes back
    in the same slot: the underside is unreachable once the board is in the Lian Li, and
    reseating it restores the known-good configuration. Identify it in software after
    first boot (below), not on the bench.
  - **Thermal pads — check every M.2 pad before the board goes in.** At least one shipped
    with its protective film never peeled, so that drive has run with no heatsink contact
    for the life of the box. Peel the film on both M.2 slots and the chipset pad; replace
    any pad that is hardened, torn, or has taken a set. Inspect both drives for heat
    evidence (browned PCB near the controller, deformed parts) while they are in hand.
    This is a two-minute check that cannot be repeated once the board is mounted.
- NH-U12A gotchas: the box has **two** manuals — use the one headed **AM5, AM4**, not the
  LGA leaflet. Intel parts are `NM-I*`, AMD parts are `NM-A*`; if a part number in hand has
  an I after the NM-, it is the wrong kit. AM4 has no hole-position choice (that is an
  Intel-only step). Before mounting: unscrew the **four grey NZXT standoffs** the Kraken
  left threaded into the AM4 backplate and bag them with the AIO so it stays sellable.
  Clean the IHS before the NT-H1.
- Fans — the board has **three** headers (`CPU_FAN`, `SYS_FAN1`, `SYS_FAN2`), all 4-pin,
  each rated **2A / 24W** (manual p.16). That is generous: a 120mm fan draws ~0.1-0.25A, so
  one header carries three of them on a passive splitter with room to spare. **No powered
  hub needed.**
  - `CPU_FAN`: both NH-U12A fans via Noctua's supplied 4-pin Y-cable, on the CPU curve.
  - `SYS_FAN1`: the three bottom intakes, on a 3-way splitter.
  - `SYS_FAN2`: rear exhaust.
  - Only one fan per splitter reports RPM; the rest are controlled but invisible. Harmless.
  - **Check the fan connectors:** 4-pin = PWM. **3-pin = DC** — still fine here, but set
    that header to DC mode in BIOS or the fan runs at 100% forever.
  - BIOS fan curves (Smart Fan 6, F6). **These are not managed by Nix and a CMOS clear
    wipes them**, so they are recorded here:
    - Case fans: `Fan Control Use Temperature Input` = **System**, the ambient board
      sensor. Not CPU (Ryzen Tctl spikes 10-20C in milliseconds and the fans surge), not
      MOS or Chipset (they track CPU and I/O load, not case heat). `System` is also the
      only option that picks up GPU heat, which under llama-swap load is the biggest
      source in the box.
    - `Temperature Interval` = 3-5C for hysteresis, or the fans hunt at a threshold.
    - `Fan Stop` = **Disabled** (the default). Zero-RPM is a bad trade here: passively
      cooled X570 chipset, dusty location, nobody listening.
    - `FAN Control Mode` = PWM for 4-pin, Voltage for 3-pin.
    - Floor around 30-40% with a gentle ramp; tune from NixOS with `lm_sensors` under real
      load once it is up.
  - Lights are not wanted on a headless box under the stairs: leave any proprietary RGB
    leads coiled and unplugged, and skip the RGB hub entirely. **Never plug a proprietary
    4-pin RGB connector into a motherboard 12V RGB header** — it fits and the pinout is
    wrong. One less hub, one less cable run, one less failure mode.
  - Right-size the count: two or three case fans is plenty here. Under the stairs the
    problem is dust and restricted airflow, so favour filtered intakes and mild positive
    pressure over fan count.
  - Airflow: **bottom = intake** (open blade face down), top/rear = exhaust. Bottom intake
    feeds the 3080 Ti directly, works with convection, and is the only orientation that
    uses the bottom dust filter. Three bottom intakes plus one rear exhaust gives positive
    pressure, which is what a dusty spot wants; do not populate every mount beyond that. The
    NH-U12A points at the rear vent, so it assists exhaust for free. Fan frames carry two
    moulded arrows (airflow, rotation); air exits the side with the motor struts.
  - The SF750 has its own intake and filter section — do not count its vent as a fan mount
    or block it.
- Lian Li build: board in, NH-U12A on (NT-H1 in box; fans clear of DIMMs, can slide up),
  3080 Ti in, SF750 in (check SFX bracket), both pool drives connected, mystery M.2 back
  in the underside slot **before** the board goes in.
- First boot at the desk, monitor on the 3080 Ti (same NVIDIA driver, no config change):
  - Boots the pre-diet or diet config depending on merge timing; converge fixes drift:
    `sudo systemctl start cosmo-rebuild` (or wait for the hourly timer).
  - Sanity: `zpool status -x` → both pools; `nvidia-smi` → 3080 Ti; `tailscale status`.
  - If it doesn't boot: the mystery M.2 may carry its own ESP. BIOS NVRAM travels with the
    board so the boot order should be intact, but if CMOS got cleared, F11 → pick the WD
    drive, then fix the boot order. Not a sign anything is broken.
  - If `tank` is missing it is not lane sharing: the manual documents four chipset SATA
    ports and two M.2 sockets with no shared-bandwidth or disable note anywhere. Treat a
    missing `tank` as a cable or drive problem.
- Relocate under stairs: 2.5GbE into the switch/UDM (same MAC → same IP 192.168.1.28,
  PXE config unchanged), power, boot unattended.
  - **Not on carpet.** Bottom intake draws the dirtiest air in the room; on carpet the feet
    sink, the intake chokes and it pulls fibres into the filter. Stand it on a hard
    surface (shelf, paver, offcut) with real clearance under the feet. This decision
    dominates the week-later temps/dust check.

### Service sweep (over SSH)

```
lsblk -o NAME,MODEL,SERIAL,SIZE       # is the mystery M.2 there? rpool = WDS100T1X0E-00AFY0
for d in /dev/nvme?n1; do nvme smart-log "${d%n1}" | \
  grep -iE 'temperature|critical_comp|warning_temp|media_errors|unsafe|percentage'; done
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
- Identify the mystery M.2: `nvme id-ctrl /dev/nvme1` + `blkid` for contents. Label is
  peeled, so software is the only read. Decide keep / wipe / pull, and record it in
  `classic-laddie-hardware.md` — which currently lists only the two pool drives. If it
  never appears, the chipset slot is disabled in BIOS or the drive is dead; either way it
  is inert and can wait for the next time the board is out.
- Read the thermal damage question off SMART on **both** drives: `warning_temp_time` and
  `critical_comp_time` are lifetime minutes above the thresholds, so large non-zero values
  mean a drive has been cooking with its film-covered pad. Pair with `media_errors` and
  `percentage_used`. A cooked mystery drive justifies a future teardown to pull it; a
  cooked SN850 is a replacement plan for `rpool` while the pool is still healthy.
- Watch crash-capture on laddie: does the silent-lockup history follow the ITX board?
  The underside M.2 is the leading physical suspect — an NVMe that overheats and drops off
  PCIe can throw an AER storm that wedges the box with nothing in the logs, and it does
  that even for a drive no pool mounts. Peeling the pad film may have fixed it outright.
  Note that the move confounds this (new case, PSU, GPU, cooler), so lean on SMART and
  `journalctl -k | grep -i 'aer\|pcieport\|nvme'` rather than on lockups recurring or not.
- Valley attest from weller: registry `signs:` grant + env vars (tracked in runbook).
- Week-later: temps/dust under the stairs, UPS decision.
