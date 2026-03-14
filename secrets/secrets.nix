let
  keys = import ./keys.nix;
in
{
  "user-password.age".publicKeys = keys.users ++ keys.hosts;
  "media-vpn.age".publicKeys = keys.users ++ keys.hosts;
  "sonarr-api-key.age".publicKeys = keys.users ++ keys.hosts;
  "radarr-api-key.age".publicKeys = keys.users ++ keys.hosts;
  "prowlarr-api-key.age".publicKeys = keys.users ++ keys.hosts;
  "ha-location.age".publicKeys = keys.users ++ keys.hosts;
}
