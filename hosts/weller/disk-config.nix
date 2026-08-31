# Disko configuration for weller
# Seagate FireCuda 510 NVMe (1.86TB) — the same physical drive as the pre-2026
# weller, carried over from the dead X570 build and wiped for the rebuild.
#
# Unencrypted ZFS root. No whole-disk encryption and no ZFS native encryption:
# this is a desktop that must boot unattended for Sunshine streaming.
#
# To apply during installation:
#   sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko ./hosts/weller/disk-config.nix
#
# To find the correct disk by-id, run: ls -la /dev/disk/by-id/ | grep -i seagate
# WARNING: This will wipe the specified disk!
{
  disko.devices = {
    disk.main = {
      device = "/dev/disk/by-id/nvme-Seagate_FireCuda_510_SSD_ZP2000GM30001_7QE00F0P";
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "1G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [
                "fmask=0022"
                "dmask=0022"
              ];
            };
          };
          # A real partition, not a zvol: swapping onto a zvol deadlocks under
          # memory pressure (ARC reclaim needs allocations to page out).
          # Plain, no randomEncryption. Sized against DDR5 capacity; no
          # hibernation requirement, so this is not a resumeDevice.
          swap = {
            size = "32G";
            content = {
              type = "swap";
              randomEncryption = false;
            };
          };
          zfs = {
            size = "100%";
            content = {
              type = "zfs";
              pool = "wpool";
            };
          };
        };
      };
    };

    # "wpool", not "rpool"/"tank" — distinct from classic-laddie's pools so a
    # rescue import of this disk on that host can never collide.
    zpool.wpool = {
      type = "zpool";
      options = {
        ashift = "12";
        autotrim = "on";
      };
      rootFsOptions = {
        compression = "zstd";
        atime = "off";
        xattr = "sa";
        acltype = "posixacl";
        mountpoint = "none";
        "com.sun:auto-snapshot" = "false";
      };

      datasets = {
        root = {
          type = "zfs_fs";
          mountpoint = "/";
          options.mountpoint = "legacy";
        };
        # Nix store: reproducible from the flake, never worth snapshotting.
        nix = {
          type = "zfs_fs";
          mountpoint = "/nix";
          options.mountpoint = "legacy";
        };
        # Its own dataset so it can be snapshotted and `zfs send` to
        # classic-laddie's tank/personal.
        home = {
          type = "zfs_fs";
          mountpoint = "/home";
          options.mountpoint = "legacy";
        };
      };
    };
  };
}
