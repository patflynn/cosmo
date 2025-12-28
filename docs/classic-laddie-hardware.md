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

## Network Interfaces
*   **Wired Ethernet:** Intel Corporation Ethernet Controller I225-V [8086:15f3]
*   **Wireless:** MEDIATEK Corp. MT7921K (RZ608) Wi-Fi 6E 80MHz [14c3:0608]

## Graphics Processing Unit (GPU)
*   **Model:** NVIDIA Corporation GA102 [GeForce RTX 3080 Ti] [10de:2208]
*   **Driver in use:** nouveau

## Conclusion on VM Resources
*   **CPU:** Abundant (32 threads available). Allocating 2 vCPUs to `johnny-walker` is perfectly fine.
*   **RAM:** Ample (27GiB free). Allocating 4GiB to `johnny-walker` is well within limits.
*   **Storage:** The 3.6TiB ZFS drive (`/dev/sda`) is suitable for hosting VM disk images or for the shared storage used by MicroVMs. The 931.5GiB NVMe is used by the host OS.

This detailed overview provides good context for further VM planning and resource allocation.
