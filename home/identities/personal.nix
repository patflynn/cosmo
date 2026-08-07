{ ... }:
let
  user = {
    name = "Patrick Flynn";
    email = "big.pat@gmail.com";
  };
in
{
  programs.git.settings.user = user;
  programs.jujutsu.settings.user = user;
}
