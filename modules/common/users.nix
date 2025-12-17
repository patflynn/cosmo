{ pkgs, ... }:

{
  programs.zsh.enable = true;

  users.users.patrick = {
    isNormalUser = true;
    shell = pkgs.zsh;
    extraGroups = [ "wheel" "networkmanager" ];

    # Shared password hash
    hashedPassword = "$6$ZtyAYsmFObdDrWxk$t/B4v4b8hHt3gSIjDiLy70fVwrzjjxC9/MRKAWuG/gQqlLZ/PVVclOR1bihX7l/RI8MLPUTS1vjV.ch8tYRb0/";

    openssh.authorizedKeys.keys = [
      # makers-mark.ubuntu
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILc8u2oEFD+sn9vmX0gEbf62V4fmHGSvu10ENPkci3Yd"
      # makers-mark.nixos
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG8B2eVhu/TpXZPyOt/6w0ELdtO6X6cTiWz3CvofxDCR"
      # Chrome Secure Shell
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHo0Oc728AfV2EMn30DhTWSqdWhmY8xR6np/qf6U7xvn cloud-ssh"
    ];
  };
}
