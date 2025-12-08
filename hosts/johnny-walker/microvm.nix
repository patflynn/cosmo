{ pkgs, ... }:

{
  microvm = {
    hypervisor = "qemu";
    mem = 20480;
    vcpu = 24;

    # Shared directory for persistent data (like a virtual disk)
    shares = [ {
      source = "/nix/store";
      mountPoint = "/nix/store";
      tag = "store";
      proto = "virtiofs";
    } {
      source = "/var/lib/microvms/johnny-walker/etc";
      mountPoint = "/etc";
      tag = "etc";
      proto = "virtiofs";
    } {
      source = "/var/lib/microvms/johnny-walker/home";
      mountPoint = "/home";
      tag = "home";
      proto = "virtiofs";
    } {
      source = "/var/lib/microvms/johnny-walker/var-lib";
      mountPoint = "/var/lib";
      tag = "var-lib";
      proto = "virtiofs";
    } ];

    interfaces = [ {
      type = "macvtap";
      id = "vm-net"; 
      mac = "02:00:00:00:00:01";
      macvtap = {
        link = "enp4s0"; # The physical interface on classic-laddie
        mode = "bridge"; 
      };
    } ];
  };
}
