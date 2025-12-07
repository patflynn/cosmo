{ pkgs, ... }:

{
  microvm = {
    hypervisor = "qemu";
    mem = 4096;
    vcpu = 2;

    # Shared directory for persistent data (like a virtual disk)
    shares = [ {
      source = "/var/lib/microvms/johnny-walker/etc";
      mountPoint = "/etc";
      tag = "etc";
      proto = "virtiofs";
    } {
      source = "/var/lib/microvms/johnny-walker/home";
      mountPoint = "/home";
      tag = "home";
      proto = "virtiofs";
    } ];

    interfaces = [ {
      type = "user"; # User-mode networking (slirp) for easiest setup without root bridge config
      id = "vm-net";
      mac = "02:00:00:00:00:01";
    } ];
  };
}
