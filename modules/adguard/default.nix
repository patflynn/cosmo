# Network-wide DNS filtering for the LAN.
#
# AdGuard Home rather than Pi-hole: Pi-hole ships no NixOS module and keeps its
# blocklists, groups and local records in a mutable SQLite database behind a web
# UI — exactly the drift this repo exists to prevent. AdGuard has a native
# module, so the resolver is described here instead, and `mutableSettings =
# false` makes that literal: the config is copied fresh from the store on every
# start, so anything changed in the web UI is discarded on the next restart.
# Change things in this file, not there.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.adguard;

  # Stand-in for the real admin hash, substituted at service start from
  # cfg.passwordHashFile. Shaped like a bcrypt digest so AdGuard's build-time
  # `--check-config` has nothing to object to, and hashes nothing: an all-'A'
  # digest has no preimage, so a placeholder that somehow survives to runtime
  # fails closed rather than granting access.
  passwordPlaceholder = "$2y$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";

  # AdGuard stores local records as a list of {domain, answer} pairs; the option
  # takes the friendlier attrset.
  dnsRewrites = lib.mapAttrsToList (domain: answer: { inherit domain answer; }) cfg.localRecords;

  # The generated YAML lands world-readable in /nix/store and this repo is
  # public, so the hash can live in neither. Injected as root (the `+` prefix on
  # ExecStartPre below) into the state file the service actually reads, after
  # the module's own preStart has installed the store copy over it — mkAfter is
  # what orders it last.
  injectPassword = pkgs.writeShellScript "adguardhome-inject-password" ''
    set -euo pipefail

    conf=/var/lib/AdGuardHome/AdGuardHome.yaml
    placeholder='${passwordPlaceholder}'
    hash=$(head -n1 ${cfg.passwordHashFile})

    if [ -z "$hash" ]; then
      echo "adguardhome: ${cfg.passwordHashFile} is empty, refusing to start" >&2
      exit 1
    fi

    ${pkgs.gnused}/bin/sed -i "s|$placeholder|$hash|" "$conf"
  '';
in
{
  options.modules.adguard = {
    enable = lib.mkEnableOption "AdGuard Home DNS filtering for the LAN";

    lanAddress = lib.mkOption {
      type = lib.types.str;
      example = "192.168.1.28";
      description = ''
        Address :53 is bound to. Deliberately not 0.0.0.0: libvirt's dnsmasq
        already holds 192.168.122.1:53 on a virtualization host, and a wildcard
        bind races it.
      '';
    };

    lanInterface = lib.mkOption {
      type = lib.types.str;
      example = "enp4s0";
      description = ''
        Interface the :53 firewall hole is scoped to. Scoped rather than global
        so the resolver is never reachable over Tailscale or its funnel — an
        open resolver on the internet is a reflection amplifier.
      '';
    };

    webAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = ''
        Address the admin UI binds to. Loopback by default: with no
        passwordHashFile set AdGuard has no login at all, and even with one the
        UI can repoint every DNS answer in the house. Reach it over an SSH
        tunnel, or set this to a Tailscale address.
      '';
    };

    webPort = lib.mkOption {
      type = lib.types.port;
      default = 3000;
      description = ''
        Admin UI port. Not 80/443 — Caddy owns those on classic-laddie.
        No firewall hole is opened for it; see webAddress.
      '';
    };

    upstreams = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "https://dns.quad9.net/dns-query" ];
      description = ''
        Upstream resolvers. DNS-over-HTTPS by default, so the ISP sees one TLS
        connection instead of every domain the house looks up.
      '';
    };

    localRecords = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        jellyfin = "192.168.1.28";
      };
      description = ''
        hostname -> IP records answered for the LAN. Replaces the hand-entered
        Local DNS records on the router.
      '';
    };

    passwordHashFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/run/agenix/adguard-password";
      description = ''
        File whose first line is the bcrypt hash of the admin password
        (`htpasswd -B -n -C 10 admin`, hash half only). Null leaves the UI with
        no login, which is only safe while webAddress stays on loopback.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.adguardhome = {
      enable = true;

      # The whole point: no state behind the UI. Every restart reinstalls the
      # config below, so the git history is the configuration history.
      mutableSettings = false;

      host = cfg.webAddress;
      port = cfg.webPort;

      # openFirewall would open the UI port on every interface, Tailscale
      # included. The DNS hole below is interface-scoped instead.
      openFirewall = false;

      settings = {
        users = lib.optional (cfg.passwordHashFile != null) {
          name = config.cosmo.user.default;
          password = passwordPlaceholder;
        };
        auth_attempts = 5;
        block_auth_min = 15;

        dns = {
          bind_hosts = [
            cfg.lanAddress
            "127.0.0.1"
          ];
          port = 53;
          upstream_dns = cfg.upstreams;
          # Plain-IP resolvers used only to resolve the DoH upstream's own
          # hostname. Chicken-and-egg: these cannot themselves be DoH.
          bootstrap_dns = [
            "9.9.9.9"
            "149.112.112.112"
          ];
          # AdGuard's default is 20 q/s per client, which a single browser
          # opening a tab full of trackers blows straight through. The LAN is
          # not the threat model here; the interface-scoped firewall is.
          ratelimit = 0;
          enable_dnssec = true;
          cache_size = 33554432;
          cache_ttl_min = 60;
          cache_optimistic = true;
        };

        filtering = {
          protection_enabled = true;
          filtering_enabled = true;
          rewrites_enabled = true;
          rewrites = dnsRewrites;
        };

        # Two lists on purpose. The aggressive ones (HaGeZi Ultimate, OISD Big)
        # break checkout flows and app telemetry that some devices treat as
        # fatal, and every breakage costs a debugging session that starts with
        # "is the internet broken?". Add more here if you want them, in git.
        filters = [
          {
            enabled = true;
            id = 1;
            name = "AdGuard DNS filter";
            url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt";
          }
          {
            enabled = true;
            id = 3;
            name = "Peter Lowe's Blocklist";
            url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_3.txt";
          }
        ];

        querylog = {
          enabled = true;
          interval = "168h";
        };

        statistics = {
          enabled = true;
          interval = "168h";
        };
      };
    };

    # Runs last, as root, after the module's preStart has laid down the store
    # copy of the config. See injectPassword above.
    systemd.services.adguardhome.serviceConfig.ExecStartPre = lib.mkAfter (
      lib.optional (cfg.passwordHashFile != null) "+${injectPassword}"
    );

    networking.firewall.interfaces.${cfg.lanInterface} = {
      allowedTCPPorts = [ 53 ];
      allowedUDPPorts = [ 53 ];
    };
  };
}
