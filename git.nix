

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
