{
  config,
  lib,
  ...
}:

let
  cfg = config.modules.firmware;
in
{
  options.modules.firmware = {
    enable = lib.mkEnableOption "Firmware updates via fwupd (LVFS)";
  };

  config = lib.mkIf cfg.enable {
    # ---------------------------------------------------------------------------
    # fwupd — vendor firmware updates pulled from the Linux Vendor Firmware
    # Service. Covers NVMe drives, TPMs, docks, and UEFI system firmware for
    # vendors that publish there. Query with `fwupdmgr get-devices` and
    # `fwupdmgr refresh && fwupdmgr get-updates`.
    #
    # Coverage caveat: participation is per-vendor. GIGABYTE ships to LVFS only
    # for its server line (via Redfish), and MSI does not ship consumer boards
    # at all, so neither classic-laddie's AORUS board nor weller's MSI X870E is
    # covered — a BIOS update on those still means the vendor's own flashing
    # tool from a FAT32 USB stick (Q-Flash / M-Flash). fwupd is enabled anyway
    # because it does see the peripheral firmware on these hosts, and it gives
    # one place to check rather than none.
    #
    # UEFI capsule updates stage into the ESP. EspLocation defaults to
    # boot.loader.efi.efiSysMountPoint (/boot on both bare-metal hosts), which
    # has ample free space, so no override is needed here.
    #
    # The `lvfs-testing` remote carries firmware not yet promoted to stable. It
    # is deliberately left off — a bad UEFI capsule flash is not something you
    # recover from over SSH. Opt in per-host if chasing a specific pre-release
    # fix: services.fwupd.extraRemotes = [ "lvfs-testing" ];
    # ---------------------------------------------------------------------------
    services.fwupd.enable = true;
  };
}
