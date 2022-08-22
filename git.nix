

{ config, pkgs, ... }:

{
  programs.git = {
    enable = true;
    ignores = [ "*~" "*.swp" ];
    userEmail = "patrick@chainguard.dev";
    userName = "Patrick Flynn";
    extraConfig.pull.rebase = "true";
    extraConfig.github.user = "patflynn";
    extraConfig.init.defaultBranch = "main";
    extraConfig.push.autoSetupRemote = true;
  };
}
