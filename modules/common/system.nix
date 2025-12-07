{ pkgs, ... }:

{
  # Core System Packages
  # These are installed system-wide and available to all users (including root).
  environment.systemPackages = with pkgs; [
    # Editors
    vim
    emacs

    # Network Tools
    wget
    curl
    
    # System Monitor
    htop
    
    # Version Control
    git
  ];
}
