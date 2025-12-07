{ pkgs, ... }:

{
  # Guest Agent for KVM/QEMU
  services.qemuGuest.enable = true;
  services.spice-vdagentd.enable = true; # Improved copy/paste and resolution scaling
}
