{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.modules.initrd-bluetooth;
in
{
  options.modules.initrd-bluetooth = {
    enable = lib.mkEnableOption "Bluetooth in initrd for BLE keyboard at LUKS prompt";

    pairingDir = lib.mkOption {
      type = lib.types.path;
      description = "Path to directory mirroring /var/lib/bluetooth/ structure (contains pairing keys)";
    };
  };

  config = lib.mkIf cfg.enable {
    # -----------------------------------------------------------------------
    # Kernel modules for Bluetooth HID
    # -----------------------------------------------------------------------
    boot.initrd.availableKernelModules = [
      "bluetooth"
      "btusb"
      "btrtl"
      "hidp"
      "hid_generic"
    ];

    # -----------------------------------------------------------------------
    # D-Bus (required by bluetoothd)
    # -----------------------------------------------------------------------
    boot.initrd.systemd.dbus.enable = true;

    # -----------------------------------------------------------------------
    # Firmware, D-Bus policy, BlueZ config, and pairing keys
    #
    # The dbus module creates /etc/dbus-1 as a symlink to a read-only store
    # path via makeDBusConf, so we cannot place files inside it via
    # boot.initrd.systemd.contents.  Instead, override the dbus config to
    # include our bluetooth policy in the generated config.
    # -----------------------------------------------------------------------
    boot.initrd.systemd.contents = {
      "/lib/firmware/rtl_bt".source = "${pkgs.linux-firmware}/lib/firmware/rtl_bt";

      "/etc/dbus-1".source =
        let
          bluetoothDbusPolicy = pkgs.writeTextDir "share/dbus-1/system.d/bluetooth.conf" ''
            <!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-BUS Bus Configuration 1.0//EN"
              "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
            <busconfig>
              <policy context="default">
                <allow own="org.bluez"/>
                <allow send_destination="org.bluez"/>
                <allow send_interface="org.bluez"/>
                <allow send_interface="org.freedesktop.DBus.ObjectManager"/>
                <allow send_interface="org.freedesktop.DBus.Properties"/>
              </policy>
            </busconfig>
          '';
        in
        lib.mkForce (
          pkgs.makeDBusConf.override {
            suidHelper = "/bin/false";
            serviceDirectories = [
              pkgs.dbus
              config.boot.initrd.systemd.package
              bluetoothDbusPolicy
            ];
          }
        );

      "/etc/bluetooth/main.conf".text = ''
        [General]
        FastConnectable = true
        JustWorksRepairing = always
        Experimental = true

        [LE]
        MinConnectionInterval = 6
        MaxConnectionInterval = 9
        ConnectionLatency = 0

        [Policy]
        AutoEnable = true
        ReconnectAttempts = 7
        ReconnectIntervals = 1,2,4,8,16,32,64
      '';

      "/var/lib/bluetooth".source = cfg.pairingDir;
    };

    # -----------------------------------------------------------------------
    # bluetoothd service
    # -----------------------------------------------------------------------
    boot.initrd.systemd.services.bluetooth = {
      description = "Bluetooth service (initrd)";
      after = [
        "dbus.socket"
        "systemd-udevd.service"
      ];
      before = [ "cryptsetup.target" ];
      wantedBy = [ "sysinit.target" ];
      serviceConfig = {
        Type = "dbus";
        BusName = "org.bluez";
        ExecStart = "${pkgs.bluez}/libexec/bluetooth/bluetoothd --debug -P battery,deviceinfo,network,sap";
        Restart = "on-failure";
        RestartSec = "1";
      };
      path = [
        pkgs.bluez
        pkgs.dbus
      ];
    };
  };
}
