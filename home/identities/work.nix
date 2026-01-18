{ ... }:
{
  cosmo.gemini.enable = false;

  programs.git = {
    settings = {
      user = {
        name = "Patrick Flynn";
        email = "paflynn@google.com";
      };
    };
  };
}
