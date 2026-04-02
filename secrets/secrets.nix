let
  keys = import ./keys.nix;
in
{
  # User password needed on all interactive hosts
  "user-password.age".publicKeys = keys.users ++ keys.hosts.main ++ [ keys.hosts.reel-life-0 ];

  # Media/Home Infrastructure
  "media-vpn.age".publicKeys = keys.users ++ keys.hosts.main;
  "sonarr-api-key.age".publicKeys = keys.users ++ keys.hosts.main;
  "radarr-api-key.age".publicKeys = keys.users ++ keys.hosts.main;
  "prowlarr-api-key.age".publicKeys = keys.users ++ keys.hosts.main;
  "ha-location.age".publicKeys = keys.users ++ keys.hosts.main;

  # Anthropic API Key (Shared by reel-life and klaus-worker)
  "anthropic-key.age".publicKeys = keys.users ++ keys.hosts.main;

  # GitHub Token (Optional override for klaus-worker)
  "github-token.age".publicKeys = keys.users ++ keys.hosts.main;

  # Reel-life specific
  "reel-life-telegram-token.age".publicKeys = keys.users ++ keys.hosts.main;
  "reel-life-media-keys.age".publicKeys = keys.users ++ keys.hosts.main;
}
