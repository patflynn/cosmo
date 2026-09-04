{ ... }:

{
  imports = [ ./work.nix ];

  # Claude-code, Klaus, and Codex are blacklisted on work macOS due to corporate policies
  cosmo.klaus.enable = false;
  cosmo.codex.enable = false;
}
