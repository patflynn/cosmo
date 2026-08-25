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
    # Coverage caveat: participation is per-vendor, and GIGABYTE ships to LVFS
    # only for its server line (via Redfish). The consumer AORUS desktop boards
    # in classic-laddie and weller are NOT covered, so a BIOS update on those
    # still means Q-Flash from a FAT32 USB stick. fwupd is enabled anyway
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
