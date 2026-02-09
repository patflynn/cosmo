# Disko configuration for weller
# Seagate FireCuda 510 NVMe (1.86TB)
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
          luks = {
            size = "100%";
            content = {
              type = "luks";
              name = "cryptroot";
              # Password will be prompted during disko run
              settings = {
                allowDiscards = true; # Enable TRIM for SSD
              };
              content = {
                type = "btrfs";
                extraArgs = [
                  "-L"
                  "nixos"
                ];
                subvolumes = {
                  "@root" = {
                    mountpoint = "/";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                  };
                  "@home" = {
                    mountpoint = "/home";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                  };
                  "@nix" = {
                    mountpoint = "/nix";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                  };
                  "@swap" = {
                    mountpoint = "/swap";
                    mountOptions = [ "noatime" ];
                    swap.swapfile.size = "16G";
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
