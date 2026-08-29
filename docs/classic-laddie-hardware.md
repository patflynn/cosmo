# classic-laddie Hardware Resources

This document outlines the hardware specifications of the `classic-laddie` host machine as of its last check. This information is crucial for understanding available resources for VM allocation and system planning.

## CPU
*   **Architecture:** x86_64
*   **Model:** AMD Ryzen 9 5950X 16-Core Processor
*   **Logical CPUs (Threads):** 32
*   **Sockets:** 1
*   **Cores per Socket:** 16
*   **Virtualization:** AMD-V enabled
*   **Max Frequency:** 5084.0000 MHz

## Memory (RAM)
*   **Total:** 31 GiB
*   **Used:** ~3.0 GiB
*   **Free:** ~27 GiB
*   **Available:** ~28 GiB

## Storage Devices

### Primary OS Drive (NVMe SSD)
*   **Device:** `/dev/nvme0n1`
*   **Model:** WDS100T1X0E-00AFY0
*   **Size:** 931.5 GiB (1 TB)
*   **Partitions:**
    *   `/dev/nvme0n1p1`: 976 MiB (EFI System) - Mounted at `/boot`
    *   `/dev/nvme0n1p2`: 930.6 GiB (Linux filesystem) - Main OS partition

### Data Drive (SATA SSD)
*   **Device:** `/dev/sda`
*   **Model:** SD Ultra 3D 4TB
*   **Size:** 3.64 TiB (4 TB)
*   **Partitions:**
    *   `/dev/sda1`: 3.6 TiB (Solaris /usr & Apple ZFS)
    *   `/dev/sda9`: 8 MiB (Solaris reserved 1)
*   **ZFS Configuration:**
    *   Pool: `tank`
    *   Datasets:
        *   `tank/media`: Mounted at `/mnt/media`
        *   `tank/personal`: Mounted at `/mnt/personal`

## Case & Cooling
*   **Case:** Lian Li (white/wood panels), located under the stairs. Replaced the NZXT H710
    in the 2026-08-29 laddie-split (`docs/laddie-split-playbook.md`) — `weller` took the
    workstation/gaming role and the H710 retired.
*   **Cooler:** Noctua NH-U12A (air tower). Replaced the NZXT Kraken AIO, which retired with
    the case (its LCD-orientation udev rule/oneshot are gone from `default.nix` too).

## Network Interfaces
*   **Wired Ethernet:** Intel Corporation Ethernet Controller I225-V [8086:15f3] — sole
    connectivity path; the box is headless under the stairs, wired into the switch/UDM on
    the same MAC/IP (`192.168.1.28`) it had before the move.
*   **Wireless:** MEDIATEK Corp. MT7921K (RZ608) Wi-Fi 6E 80MHz [14c3:0608]

## Console Access
*   No display/keyboard normally attached (headless). A KVM is connected under the stairs
    for local console access when needed.
*   Server-only role: PR #763 dropped desktop duty (Hyprland, `modules.gaming`,
    `modules.ddcci`, autologin) — that workstation/gaming role now lives on `weller`.
    classic-laddie keeps every server role: media-server, reel-life, github-relay, the
    valley git-hosting stack, cosmo-rebuild, home-assistant, PXE, tailscale, the klaus
    microVM host, libvirtd, crash-capture, and local LLM inference (llama-swap/open-webui).

## Graphics Processing Unit (GPU)
*   **Model:** AORUS GeForce RTX 3080 Ti Master 12GB (GV-N308TAORUS M-12GD) — NVIDIA
    Corporation GA102 [GeForce RTX 3080 Ti] [10de:2208]. Card came out of the closet in the
    2026-08-29 laddie-split; the RTX 4090 that had been here moved to `weller`.
*   **VRAM:** 12 GiB
*   **Driver in use:** `nvidia` (proprietary — `hardware.nvidia.package =
    config.boot.kernelPackages.nvidiaPackages.stable;`, `open = false`), not nouveau. Same
    driver stack as before the swap, so the move needed no config change.
*   **Already spoken for:** `services.llama-swap` (local LLM inference, see
    `hosts/classic-laddie/default.nix`) holds one 14B-class Q4_K_M model resident at a time
    (~10GB with an 8192-token KV cache), idle-unloaded. That leaves roughly 2GB of VRAM
    headroom — any GPU passthrough or additional GPU workload has to share this card, not
    add a second consumer's worth of room.

## Conclusion on VM Resources
*   **CPU:** Abundant (32 threads available). Allocating 2 vCPUs to `johnny-walker` is perfectly fine.
*   **RAM:** Ample (27GiB free). Allocating 4GiB to `johnny-walker` is well within limits.
*   **Storage:** The 3.6TiB ZFS drive (`/dev/sda`) is suitable for hosting VM disk images or for the shared storage used by MicroVMs. The 931.5GiB NVMe is used by the host OS.
*   **GPU:** Not free to plan around — see above. It's dedicated to host-side LLM inference,
    sized tightly to its own 12GB, with no spare headroom for a passthrough VM.

Board, RAM, and both ZFS-backed drives are unchanged by the 2026-08-29 hardware split; this
overview otherwise reflects the post-split machine (case, cooler, GPU, location) and its
server-only role.
