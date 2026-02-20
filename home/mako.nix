{ pkgs, ... }:

{
  home.packages = with pkgs; [
    libnotify
  ];

  services.mako = {
    enable = true;
    settings = {
      # Position & layout
      anchor = "top-right";
      layer = "overlay";
      width = 350;
      height = 150;
      margin = "10";
      padding = "12";
      border-size = 2;
      border-radius = 12;
      max-visible = 3;
      sort = "-time";

      # Catppuccin Mocha theme
      background-color = "#1e1e2eee";
      text-color = "#cdd6f4";
      border-color = "#313244";
      progress-color = "over #cba6f7";

      # Typography
      font = "JetBrainsMono Nerd Font 11";

      # Behavior
      default-timeout = 5000;
      ignore-timeout = 0;
      icons = 1;
      max-icon-size = 48;

      # Actions
      on-button-left = "dismiss";
      on-button-middle = "none";
      on-button-right = "dismiss-all";

      # Urgency: low
      "[urgency=low]" = {
        border-color = "#585b70";
        default-timeout = 3000;
      };

      # Urgency: critical
      "[urgency=critical]" = {
        border-color = "#f38ba8";
        default-timeout = 0;
      };
    };
  };
}
