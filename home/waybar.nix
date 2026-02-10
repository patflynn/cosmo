{ pkgs, ... }:

{
  home.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    playerctl
    bluetuith
  ];

  programs.waybar = {
    enable = true;
    systemd.enable = true;
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        margin-top = 5;
        margin-left = 10;
        margin-right = 10;
        modules-left = [
          "hyprland/workspaces"
          "clock"
        ];
        modules-center = [ ];
        modules-right = [
          "mpris"
          "group/cpu-info"
          "custom/gpu"
          "memory"
          "disk"
          "network"
          "bluetooth"
          "tray"
        ];

        "group/cpu-info" = {
          orientation = "horizontal";
          modules = [
            "cpu"
            "temperature"
          ];
        };

        "hyprland/workspaces" = {
          format = "{id}";
          on-click = "activate";
          persistent-workspaces = {
            "*" = 5;
          };
        };

        clock = {
          format = "{:%H:%M}";
          format-alt = "{:%a, %b %d}";
          tooltip-format = "<tt><small>{calendar}</small></tt>";
          calendar = {
            mode = "year";
            mode-mon-col = 3;
            weeks-pos = "left";
            format = {
              months = "<span color='#f5e0dc'><b>{}</b></span>";
              days = "<span color='#cdd6f4'>{}</span>";
              weeks = "<span color='#94e2d5'><b>W{}</b></span>";
              weekdays = "<span color='#f9e2af'><b>{}</b></span>";
              today = "<span color='#cba6f7'><b><u>{}</u></b></span>";
            };
          };
        };

        mpris = {
          format = "{player_icon} {title} — {artist}";
          format-paused = "{status_icon} <i>{title} — {artist}</i>";
          title-len = 30;
          format-stopped = "󰝚";
          player-icons = {
            default = "󰝚";
          };
          status-icons = {
            paused = "󰏤";
          };
        };

        temperature = {
          format = "{temperatureC}°C";
          critical-threshold = 80;
          format-critical = "{temperatureC}°C";
          hwmon-path = "/sys/class/hwmon/hwmon2/temp1_input";
        };

        cpu = {
          format = "󰻠 {usage}%";
          interval = 2;
          on-click = "kitty btop";
        };

        "custom/gpu" = {
          exec = ''nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null | awk -F', ' '{printf "{\"text\": \"󰢮 %s%% %s°C\", \"tooltip\": \"RTX 4090\\nUsage: %s%%\\nTemp: %s°C\"}", $1, $2, $1, $2}' '';
          return-type = "json";
          interval = 5;
          on-click = "kitty btop";
        };

        memory = {
          format = "󰍛 {percentage}%";
          format-alt = "󰍛 {used:0.1f}/{total:0.1f} GB";
          tooltip-format = "RAM: {used:0.1f}/{total:0.1f} GB\nSwap: {swapUsed:0.1f}/{swapTotal:0.1f} GB";
        };

        disk = {
          format = "󰋊 {percentage_used}%";
          format-alt = "󰋊 {used}/{total}";
          path = "/";
        };

        network = {
          format-wifi = " {signalStrength}%";
          format-ethernet = "󰈀 {ipaddr}";
          format-disconnected = "󰖪 ";
          tooltip-format = "{ifname}: {ipaddr}\n⬆ {bandwidthUpBits} ⬇ {bandwidthDownBits}";
        };

        bluetooth = {
          format = "󰂯";
          format-connected = "󰂱 {device_alias}";
          format-connected-battery = "󰂱 {device_alias} {device_battery_percentage}%";
          format-disabled = "󰂲";
          format-off = "󰂲";
          tooltip-format-connected = "{device_enumerate}";
          tooltip-format-enumerate-connected-battery = "{device_alias}: {device_battery_percentage}%";
          on-click = "kitty bluetuith";
        };

        tray = {
          icon-size = 16;
          spacing = 8;
        };
      };
    };

    style = ''
      /* --- Catppuccin Mocha Palette --- */
      @define-color base #1e1e2e;
      @define-color mantle #181825;
      @define-color surface0 #313244;
      @define-color surface1 #45475a;
      @define-color text #cdd6f4;
      @define-color subtext0 #a6adc8;
      @define-color mauve #cba6f7;
      @define-color lavender #b4befe;
      @define-color sky #89dceb;
      @define-color green #a6e3a1;
      @define-color peach #fab387;
      @define-color yellow #f9e2af;
      @define-color teal #94e2d5;
      @define-color blue #89b4fa;
      @define-color red #f38ba8;
      @define-color flamingo #f2cdcd;

      /* --- Global --- */
      * {
        font-family: "JetBrainsMono Nerd Font";
        font-size: 13px;
        font-weight: 600;
        min-height: 0;
      }

      window#waybar {
        background: transparent;
      }

      tooltip {
        background-color: alpha(@base, 0.9);
        border: 2px solid @surface0;
        border-radius: 12px;
        color: @text;
      }

      tooltip label {
        color: @text;
      }

      /* --- Pill Containers --- */
      #workspaces,
      #clock,
      #mpris,
      #memory,
      #disk,
      #network,
      #bluetooth,
      #custom-gpu,
      #tray {
        background-color: alpha(@base, 0.85);
        border: 2px solid @surface0;
        border-radius: 12px;
        padding: 0 12px;
        margin: 2px 3px;
        color: @text;
      }

      /* --- CPU Group (usage + temp in one pill) --- */
      #cpu-info {
        background-color: alpha(@base, 0.85);
        border: 2px solid @surface0;
        border-radius: 12px;
        padding: 0 4px;
        margin: 2px 3px;
      }

      #cpu-info #cpu,
      #cpu-info #temperature {
        background: transparent;
        border: none;
        border-radius: 0;
        padding: 0 4px;
        margin: 0;
      }

      /* --- Workspaces --- */
      #workspaces button {
        color: @subtext0;
        padding: 0 6px;
        border-radius: 10px;
        transition: all 0.2s ease;
      }

      #workspaces button:hover {
        background-color: alpha(@surface1, 0.6);
        color: @text;
      }

      #workspaces button.active {
        color: @base;
        background-color: @mauve;
      }

      /* --- Module Accent Colors --- */
      #clock {
        color: @lavender;
      }

      #mpris {
        color: @mauve;
      }

      #temperature {
        color: @peach;
      }

      #temperature.critical {
        color: @red;
        animation: blink 0.5s ease infinite alternate;
      }

      #cpu {
        color: @sky;
      }

      #custom-gpu {
        color: @flamingo;
      }

      #memory {
        color: @green;
      }

      #disk {
        color: @yellow;
      }

      #network {
        color: @teal;
      }

      #network.disconnected {
        color: @subtext0;
      }

      #bluetooth {
        color: @blue;
      }

      #bluetooth.disabled,
      #bluetooth.off {
        color: @subtext0;
      }

      /* --- Animations --- */
      @keyframes blink {
        to {
          color: @flamingo;
        }
      }
    '';
  };
}
