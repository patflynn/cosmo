{ config, pkgs, lib, ... }:

{
  imports = [ ./default.nix ];
  services.emacs = {
    enable = true;
    socketActivation.enable = true;
  };

  xdg.configFile."mimeapps.list".force = true;
  xdg.mimeApps = {
    enable = true;
    defaultApplications = { "application/pdf" = "emacsclient.desktop"; };
  };
  xdg.dataFile."applications/emacsclient.desktop".text = ''
    [Desktop Entry]
    Name=EmacsClient
    GenericName=Text Editor
    Comment=Edit text
    MimeType=text/english;text/plain;text/x-makefile;text/x-c++hdr;text/x-c++src;text/x-chdr;text/x-csrc;text/x-java;text/x-moc;text/x-pascal;text/x-tcl;text/x-tex;application/x-shellscript;text/x-c;text/x-c++;
    Exec=em %F
    Icon=emacs
    Type=Application
    Terminal=false
    Categories=Development;TextEditor;
    StartupWMClass=Emacs
    Keywords=Text;Editor;
  '';

}