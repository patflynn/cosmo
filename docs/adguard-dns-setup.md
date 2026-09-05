# LAN DNS Setup (AdGuard Home)

Network-wide DNS filtering for the house, served by `classic-laddie` at
`192.168.1.28:53`. Configured declaratively in `modules/adguard/default.nix` and
enabled for the host in `hosts/classic-laddie/default.nix`.

## Why AdGuard Home and not Pi-hole

Pi-hole has no NixOS module, so it would run as a container with its blocklists,
groups and local DNS records in a mutable SQLite database edited through a web
UI — state that lives nowhere in git. AdGuard Home has a native module with the
same feature set (query log, per-client stats, rewrites, blocklists), so the
whole resolver is declared in Nix.

The module sets `mutableSettings = false`, which means the config file is copied
fresh from the Nix store on every service start. **Anything changed in the web
UI is discarded on the next restart.** Change `modules/adguard/default.nix` and
rebuild instead. The UI is for the query log and the dashboard.

## Before the first deploy

Port 53 is shared territory on this host. Confirm nothing already holds the
addresses AdGuard binds (`192.168.1.28` and `127.0.0.1`):

```bash
ss -lunp | grep :53   # expect only libvirt's dnsmasq on 192.168.122.1
ss -ltnp | grep :53
resolvectl status     # if this shows a stub listener, see below
```

* **libvirt's dnsmasq** on `192.168.122.1:53` is fine and stays — AdGuard binds
  named addresses rather than `0.0.0.0` precisely so the two do not collide.
* **systemd-resolved** is not enabled by this configuration (NetworkManager uses
  its own resolver by default), but if `resolvectl` reports a stub listener on
  `127.0.0.53`, that is harmless. Only a listener on `127.0.0.1:53` conflicts;
  clear it with `services.resolved.extraConfig = "DNSStubListener=no";`.

Also confirm the LAN interface name still matches `lanInterface` in the host
config, which the firewall hole is scoped to:

```bash
ip -br a   # expect enp4s0 carrying 192.168.1.28
```

## Deploy

```bash
cosmo-rebuild switch --flake .
systemctl status adguardhome
```

Verify resolution and filtering before pointing any client at it:

```bash
dig @192.168.1.28 example.com +short          # resolves
dig @192.168.1.28 doubleclick.net +short      # 0.0.0.0 — blocked
dig @192.168.1.28 jellyfin +short             # 192.168.1.28 — local record
```

## Point the network at it

On the UDM Pro: **Settings → Networks → (your LAN) → DHCP Name Server →
Manual → `192.168.1.28`**.

List *only* AdGuard. A secondary public resolver does not act as a failover —
clients query both and randomly bypass filtering. Devices pick the change up as
their DHCP leases renew; reboot one to test immediately.

Once that is live, the hand-entered Local DNS records for `jellyfin` and
`overseerr` on the UDM can be deleted — `localRecords` in the host config serves
them, and it stays in sync with the Caddy vhosts in
`modules/media-server/default.nix`.

**This makes `classic-laddie` a single point of failure for the whole house's
DNS.** The host reboots itself at 04:45 when it has diverged from the deployed
config (`modules.autoReboot`), which is a DNS outage of roughly a minute in the
middle of the night. Everything else — `nix build`, a failed converge — leaves
the resolver running. If that tradeoff stops being acceptable, a second AdGuard
instance on another host, listed as the secondary, is the fix.

## Optional: DNS for the tailnet

Tailscale admin console → **DNS → Nameservers → Add custom nameserver** →
`100.111.60.17` (classic-laddie's tailnet address), with **Override local DNS**.
Remote devices then get the same filtering and the same local names.

This needs AdGuard listening on the Tailscale address as well, which means
adding it to `bind_hosts` and ordering the unit after `tailscaled.service` so
the address exists at bind time. Not configured by default.

## Optional: admin login and LAN access to the UI

The UI binds to `127.0.0.1:3000` and has no login configured, so today it is
reachable only through a tunnel:

```bash
ssh -L 3000:127.0.0.1:3000 classic-laddie   # then http://localhost:3000
```

An AdGuard admin can repoint every DNS answer in the house, so exposing the UI
on the LAN requires a password first. The hash cannot go in this repo (it is
public) or in the module (the generated config is world-readable in the Nix
store), so it comes from agenix:

1. Generate the hash — the second field only, starting with `$2y$`:

   ```bash
   nix run nixpkgs#apacheHttpd -- htpasswd -B -n -C 10 patrick
   ```

2. Add the ACL entry in `secrets/secrets.nix`:

   ```nix
   "adguard-password.age".publicKeys = keys.users ++ keys.hosts;
   ```

3. Create the secret, one line containing just the hash:

   ```bash
   cd secrets && agenix -e adguard-password.age
   ```

4. Declare it and wire it up in `hosts/classic-laddie/default.nix`:

   ```nix
   age.secrets."adguard-password".file = ../../secrets/adguard-password.age;

   modules.adguard.passwordHashFile = config.age.secrets."adguard-password".path;
   ```

The module substitutes the hash into the runtime config at service start; the
store copy only ever holds an unusable placeholder. With a login in place, the
UI can be published on the LAN by adding a Caddy vhost next to the existing ones
in `modules/media-server/default.nix`:

```nix
virtualHosts."adguard".extraConfig = ''
  tls internal
  reverse_proxy localhost:3000
'';
```

## Tuning blocklists

`filters` in `modules/adguard/default.nix` carries two conservative lists
(AdGuard DNS filter + Peter Lowe's). The aggressive lists — HaGeZi Ultimate,
OISD Big — break checkout flows and app telemetry that some devices treat as
fatal. Add lists there, with an `id` not already in use, from
<https://adguardteam.github.io/HostlistsRegistry/assets/filters.json>.

To unblock a single domain, add an AdGuard rule (`@@||example.com^`) to a
top-level `user_rules` list in the module's `settings` rather than through the
UI, where the change would not survive a restart.

## Backing it out

DNS reverts the moment the router stops handing out `192.168.1.28`: set the
LAN's DHCP name server back to Auto and the house resolves through the UDM
again, whatever state the service is in. Then `modules.adguard.enable = false;`
and rebuild.
