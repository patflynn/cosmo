

{ config, pkgs, ... }:

{
  programs.git = {
    enable = true;
    ignores = [ "*~" "*.swp" ];
    userEmail = "patrick@chainguard.dev";
    userName = "Patrick Flynn";
    extraConfig.commit.gpgsign = "true";
    extraConfig.tag.gpgsign = "true";
    extraConfig.gpg.x509.program = "gitsign";
    extraConfig.gpg.format = "x509";
    extraConfig.pull.rebase = "true";
    extraConfig.github.user = "patflynn";
    extraConfig.init.defaultBranch = "main";
    extraConfig.push.autoSetupRemote = true;
  };
}
