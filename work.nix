{ config, pkgs, ... }:

{
  services.kolide-launcher = {
    enable = true;
    enrollSecretPath = "/home/patrick/.kolide/secret";
    rootDirectory = "/cache/kolide";
    additionalPackages = with pkgs; [ glib zfs networkmanager cryptsetup ];
  };
}
