# DDC/CI monitor control – allows software to read/write monitor settings
# (input source, brightness, contrast, etc.) over the I2C bus using ddcutil.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.ddcci;
in
{
  options.modules.ddcci = {
    enable = lib.mkEnableOption "DDC/CI monitor control via ddcutil";
  };

  config = lib.mkIf cfg.enable {
    # Load the i2c-dev kernel module so userspace can talk to monitors
    boot.kernelModules = [ "i2c-dev" ];

    # ddcutil ships a udev rule that grants the i2c group access to /dev/i2c-*
    services.udev.packages = [ pkgs.ddcutil ];

    # Add ddcutil to system packages for interactive use
    environment.systemPackages = [ pkgs.ddcutil ];

    # Ensure the i2c group exists for the udev rule
    users.groups.i2c = { };

    # Ensure the default user is in the i2c group for non-root DDC/CI access
    users.users.${config.cosmo.user.default}.extraGroups = [ "i2c" ];
  };
}
