{
  config,
  lib,
  pkgs,
  ...
}:

{
  # ---------------------------------------------------------------------------
  # Bluetooth – optimised for Kinesis Advantage 360 Pro (ZMK / BLE)
  # ---------------------------------------------------------------------------
  hardware.enableRedistributableFirmware = true;
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        # Keep adapter in page-scan mode for instant reconnects
        FastConnectable = "true";
        # ZMK uses "Just Works" pairing – always allow re-pairing
        JustWorksRepairing = "always";
        # Better LE handling & battery reporting
        Experimental = "true";
      };
      LE = {
        # Tighter polling interval (7.5–11.25 ms) for lower input latency
        MinConnectionInterval = 6;
        MaxConnectionInterval = 9;
        ConnectionLatency = 0;
      };
      Policy = {
        AutoEnable = "true";
        ReconnectAttempts = 7;
        ReconnectIntervals = "1,2,4,8,16,32,64";
      };
    };
  };
  # Prevent Bluetooth adapter auto-suspend (causes jitter with BT peripherals)
  boot.kernelParams = [ "btusb.enable_autosuspend=n" ];

  environment.systemPackages = with pkgs; [ bluetuith ];
}
