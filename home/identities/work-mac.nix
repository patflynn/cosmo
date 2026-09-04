{ ... }:

{
  imports = [ ./work.nix ];

  # Claude-code and Klaus are blacklisted on work macOS due to corporate policies
  cosmo.klaus.enable = false;
}
