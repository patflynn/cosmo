# Git configuration for home-manager
{ config, lib, pkgs, ... }:

{
  programs.git = {
    enable = true;
    ignores = [ "*~" "*.swp" ".DS_Store" ];
    userEmail = "big.pat@gmail.com";
    userName = "Patrick Flynn";
    extraConfig = {
      commit.gpgsign = true;
      tag.gpgsign = true;
      gpg.x509.program = "gitsign";
      gpg.format = "x509";
      pull.rebase = true;
      github.user = "patflynn";
      init.defaultBranch = "main";
      push.autoSetupRemote = true;
    };
    aliases = {
      lg = "log --color --graph --pretty=format:'%C(auto)%h -%d %s %Cgreen(%cr) %C(bold blue)<%an>%Creset'";
      st = "status";
      br = "branch --all";
      cm = "checkout master";
      co = "checkout";
      rbm = "rebase master";
      recommit = "commit -a --reuse-message=HEAD@{1}";
      uncommit = "reset --soft HEAD^";
      last = "log -1 HEAD";
    };
  };
}