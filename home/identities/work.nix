{ lib, ... }:
{
  cosmo.gemini.enable = false;

  programs.zsh.initExtra = lib.mkBefore ''
    # Source corporate configuration if it exists (e.g. from Piper/CitC)
    if [ -f "$HOME/.corp.zsh" ]; then
      source "$HOME/.corp.zsh"
    fi
  '';

  programs.git = {
    settings = {
      user = {
        name = "Patrick Flynn";
        email = "paflynn@google.com";
      };
    };
  };
}
