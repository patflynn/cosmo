{
  config,
  pkgs,
  lib,
  osConfig ? { },
  ...
}:

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
      advice = {
        skippedCherryPicks = false;
      };
      init.defaultBranch = "main";
      pull.rebase = true;
      alias = {
        # Basics
        st = "status";
        co = "checkout";
        ci = "commit";
        br = "branch";
        unstage = "reset HEAD --";
        last = "log -1 HEAD";
        lg = "log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%s%C(reset) %C(dim white)- %an%C(reset)%C(bold yellow)%d%C(reset)' --all";

        # The Power Loop
        up = "!git fetch origin && git rebase origin/main";
        start = "!git checkout main && git pull && git checkout -b";
        save = "!git add -A && git commit -m";
        pr = "!git push -u origin HEAD && gh pr create --fill";

        # Merge & Cleanup
        land = "!gh pr merge --auto --merge --delete-branch && git checkout main && git pull";
        sweep = "!git checkout main && git pull && git branch --merged main | grep -v 'main$' | xargs -r git branch -d";

        # List all aliases (The meta-alias)
        alias = "!git config --get-regexp ^alias\\. | sed -e s/^alias\\.// -e s/\\ /\\ =\\ /";
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

      # System Maintenance
      update = "if [ -e /etc/NIXOS ]; then sudo nixos-rebuild switch --no-write-lock-file --refresh --flake github:patflynn/cosmo; else home-manager switch --no-write-lock-file --refresh --flake github:patflynn/cosmo; fi";
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

      # Auto-rename tmux session to repo:branch or directory name
      if [ -n "$TMUX" ]; then
        _tmux_auto_rename_last=""
        _tmux_auto_rename() {
          local name git_root
          git_root=$(git rev-parse --show-toplevel 2>/dev/null)
          if [ -n "$git_root" ]; then
            local repo=$(basename "$git_root")
            local branch=$(git branch --show-current 2>/dev/null)
            if [ -n "$branch" ]; then
              name="''${repo}:''${branch}"
            else
              name="''${repo}:$(git rev-parse --short HEAD 2>/dev/null)"
            fi
          else
            name=$(basename "$PWD")
          fi
          if [ "$name" != "$_tmux_auto_rename_last" ]; then
            tmux rename-session "$name" 2>/dev/null
            _tmux_auto_rename_last="$name"
          fi
        }
        autoload -Uz add-zsh-hook
        add-zsh-hook precmd _tmux_auto_rename
      fi
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
