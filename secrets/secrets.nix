let
  keys = import ./keys.nix;
in
{
  "user-password.age".publicKeys = keys.users ++ keys.hosts;
  "media-vpn.age".publicKeys = keys.users ++ keys.hosts;
}
