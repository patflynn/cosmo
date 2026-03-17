# Desktop profile – a physical workstation with real display, bluetooth
# peripherals, and audio. Import this instead of workstation.nix for hosts
# where someone sits in front of the machine.
{
  imports = [
    ./workstation.nix
    ./bluetooth.nix
  ];
}
