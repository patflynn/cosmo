{ config, pkgs, ... }:

{
  # Shell & Tools
  home.packages = with pkgs; [
    # Core Tools
    ripgrep # Fast grep (Essential for Doom Emacs)
    fd # Fast find (Essential for Doom Emacs)
    jq # JSON parser
    tree # Directory viewer
    btop # Fancy htop

    # Emacs (The Editor)
  ];

  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Patrick Flynn";
        email = "big.pat@gmail.com";
      };
      init.defaultBranch = "main";
      pull.rebase = true;
      aliases = {
        st = "status";
        co = "checkout";
        ci = "commit";
        br = "branch";
        lg = "log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%s%C(reset) %C(dim white)- %an%C(reset)%C(bold yellow)%d%C(reset)' --all";
        unstage = "reset HEAD --";
        last = "log -1 HEAD";
        cleanup = "!git branch --merged | egrep -v \"(^\\*|main|master|dev)\" | xargs git branch -d";
      };
    };
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    shellAliases = {
      ll = "ls -l";
      ed = "emacsclient -t"; # Quick edit in terminal
      ".." = "cd ..";
      "..." = "cd ../..";
      g = "git";
      la = "ls -la";
      grep = "grep --color=auto";
      hm = "home-manager";
      emacs = "emacs -nw";
    };

    history = {
      size = 10000;
      path = "${config.xdg.dataHome}/zsh/history";
    };

    initContent = ''
      # Add $HOME/bin to PATH
      export PATH="$HOME/bin:$PATH"

      # Ergonomics
      setopt AUTO_CD              # cd by typing directory name
      setopt EXTENDED_HISTORY     # record timestamp of command in HISTFILE
      setopt HIST_EXPIRE_DUPS_FIRST # delete duplicates first when HISTFILE size exceeds HISTSIZE
      setopt HIST_IGNORE_DUPS     # ignore duplicated commands history list
      setopt HIST_IGNORE_SPACE    # ignore commands that start with space
      setopt HIST_VERIFY          # show command with history expansion to user before running it
      setopt SHARE_HISTORY        # share command history data
    '';
  };

  programs.tmux = {
    enable = true;
    prefix = "C-q"; # Remap prefix from 'C-b' to 'C-q'
    keyMode = "emacs";
    mouse = true; # Enable mouse support
    terminal = "screen-256color";
    historyLimit = 100000;

    extraConfig = ''
      set-option -g status-style fg=white,bg=colour23
      set -g base-index 1
      set-window-option -g mode-keys emacs
      unbind-key C-b
    '';
  };

  programs.starship = {
    enable = true;
  };

  home.sessionPath = [
    "${config.home.homeDirectory}/.config/emacs/bin"
  ];

  xdg.configFile = {
    "doom/config.el".source = ./doom/config.el;
    "doom/init.el".source = ./doom/init.el;
    "doom/packages.el".source = ./doom/packages.el;
  };

  services.emacs = {
    enable = true;
  };

  home.stateVersion = "25.11";
}
