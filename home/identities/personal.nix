{ pkgs, ... }:
{
  home.packages = with pkgs; [
    gemini-cli
  ];

  programs.git = {
    settings = {
      user = {
        name = "Patrick Flynn";
        email = "big.pat@gmail.com";
      };
    };
  };
}
