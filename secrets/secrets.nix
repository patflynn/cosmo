let
  keys = import ./keys.nix;
in
{
  # User password needed on all interactive hosts
  "user-password.age".publicKeys = keys.users ++ keys.hosts.main ++ [ keys.hosts.reel-life-0 ];

  # Media/Home Infrastructure (Main hosts only)
  "media-vpn.age".publicKeys = keys.users ++ keys.hosts.main;
  "sonarr-api-key.age".publicKeys = keys.users ++ keys.hosts.main;
  "radarr-api-key.age".publicKeys = keys.users ++ keys.hosts.main;
  "prowlarr-api-key.age".publicKeys = keys.users ++ keys.hosts.main;
  "ha-location.age".publicKeys = keys.users ++ keys.hosts.main;

  # Reel-life specific (Only for the bot and management)
  "reel-life-telegram-token.age".publicKeys =
    keys.users ++ keys.hosts.main ++ [ keys.hosts.reel-life-0 ];
  "reel-life-anthropic-key.age".publicKeys =
    keys.users ++ keys.hosts.main ++ [ keys.hosts.reel-life-0 ];
}
