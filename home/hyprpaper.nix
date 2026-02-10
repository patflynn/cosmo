{ ... }:

{
  services.hyprpaper = {
    enable = true;
    settings = {
      splash = false;
      wallpaper = [
        {
          monitor = "";
          path = "${./wallpapers/IOTY2019_winner-americas.jpg}";
          fit_mode = "contain";
        }
      ];
    };
  };
}
