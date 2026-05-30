# Repository context

## Purpose
`cosmo` is a personal Nix Flake repository that defines NixOS system configurations and Home Manager profiles for the maintainer's infrastructure (workstations, a virtualization host, a WSL machine, and a microVM worker). It is consumed by `nixos-rebuild` / `home-manager` on the target hosts; there is no third-party application or library produced here. See `README.md` and `ROADMAP.md`.

## Tech stack
- **Nix** (flakes). `flake.nix` pins `nixpkgs` to `github:nixos/nixpkgs/nixos-unstable`.
- Flake inputs declared in `flake.nix`: `agenix`, `home-manager`, `nixos-wsl`, `pre-commit-hooks` (`cachix/git-hooks.nix`), `nixos-generators`, `disko`, `klaus` (`github:patflynn/klaus`), `microvm` (`astro/microvm.nix`), `reel-life` (`gunk-dev/reel-life`), `github-relay` (`patflynn/github-relay`), `zen-browser`.
- Formatter: `nixfmt-tree` (declared as `formatter.x86_64-linux` in `flake.nix`).
- Pre-commit hooks: `nixfmt`, `detect-private-keys`, `zizmor` (configured in `flake.nix` `checks` block).
- All systems target `x86_64-linux`.

## Entry points
- `flake.nix` — the only flake. Defines `nixosConfigurations`, `homeConfigurations`, `packages.x86_64-linux`, `checks`, and `devShells`.
- `hosts/classic-laddie/default.nix` — physical virtualization host (also runs microvm host module).
- `hosts/johnny-walker/default.nix` — VM workstation hosted on `classic-laddie`; also built as a qcow image via `packages.x86_64-linux.johnny-walker-image`.
- `hosts/makers-nix/default.nix` — NixOS-WSL system.
- `hosts/weller/default.nix` — dual-boot workstation (uses `disko` for partitioning via `hosts/weller/disk-config.nix`).
- `modules/klaus-worker/default.nix` — microVM definition for the `klaus-worker-0` agent worker.
- `modules/bootstrap.nix` — bootstrap module used by `mkBootstrap` in `flake.nix` to produce installer-style systems (`classic-laddie-bootstrap`, `weller-bootstrap`).
- `home/linux.nix`, `home/crostini.nix` — base modules for the standalone `homeConfigurations` (`personal`, `paflynn@bushmills`, `patrick@crostini`, `paflynn@crostini`).

## Layout
- `flake.nix` — entry point; declares all nixos/home configurations and packages.
- `hosts/` — per-host NixOS configurations (`classic-laddie/`, `johnny-walker/`, `makers-nix/`, `weller/`).
- `home/` — Home Manager modules. `common.nix` is the shared base; `server.nix`, `desktop.nix`, `dev.nix`, `wsl.nix`, `crostini.nix`, `linux.nix` are context-specific layers. `identities/` contains `personal.nix` and `work.nix`. `doom/`, `wallpapers/`, `scripts/` hold supporting assets. Other files configure individual tools (`hyprland.nix`, `hyprlock.nix`, `hyprpaper.nix`, `hypridle.nix`, `waybar.nix`, `mako.nix`, `remoting.nix`, `monitor-input.nix`).
- `modules/` — reusable NixOS modules. `common/` holds shared system pieces (`system.nix`, `desktop.nix`, `bluetooth.nix`, `ddcci.nix`, `gaming.nix`, `guest.nix`, `health.nix`, `peripherals.nix`, `remoting.nix`, `users.nix`). `klaus-worker/` and `media-server/` are feature modules. `bootstrap.nix` sits at the top level.
- `secrets/` — Agenix-encrypted secrets (`*.age`) plus `keys.nix` (recipient public keys) and `secrets.nix` (file-to-recipient mapping).
- `docs/` — Markdown setup guides (Doom Emacs, secrets management, VM setup, Crostini, media server, weller dual-boot, etc.).
- `.github/workflows/` — CI: `ci.yml`, `build-host-image.yml`, `update-flake-lock.yml`, `update-klaus.yml`, `zizmor.yml`.

## Build, test, run
Prerequisite: Nix with flakes enabled. `direnv` is supported via `.envrc` (`use flake`).

- Enter the dev shell (also installs pre-commit hooks): `nix develop`
- Format check (as run in CI, `.github/workflows/ci.yml`): `nix develop -c nixfmt --check .`
- Apply formatting: `nix fmt` (uses `nixfmt-tree`).
- Dry-build a NixOS host (matches CI matrix `classic-laddie`, `makers-nix`, `johnny-walker`): `nix build .#nixosConfigurations.<host>.config.system.build.toplevel --dry-run`
- Dry-build a Home Manager profile (matches CI matrix `personal`, `paflynn@bushmills`, `patrick@crostini`, `paflynn@crostini`): `nix build .#homeConfigurations."<name>".activationPackage --dry-run`
- Run flake checks (includes pre-commit hooks): `nix flake check`
- Rebuild a system on the target host: `cosmo-rebuild switch --flake .` (a wrapper around `nixos-rebuild` provided by `modules/common/system.nix`; see `AGENTS.md`).
- Build the `johnny-walker` qcow image: `nix build .#johnny-walker-image`
- Build the `klaus-worker-0` microVM runner: `nix build .#klaus-worker-0`

## Conventions
- **Nix style**: 2-space indentation; functional/declarative; explicit imports (`AGENTS.md`). Formatting is enforced by `nixfmt` via the pre-commit hook and CI's `nixfmt --check`.
- **Branching**: never commit to `main`; all changes go through a PR from a feature/fix branch (`AGENTS.md`, `CLAUDE.md`).
- **Commit/PR messages**: do not include `Co-Authored-By` lines referencing Claude/Anthropic, and do not mention AI/LLM assistance (`CLAUDE.md`).
- **Host configurations**: each host directory under `hosts/` contains a `default.nix` and (where applicable) a `hardware-configuration.nix` / `hardware.nix`; new hosts are wired in via `flake.nix` `nixosConfigurations`.
- **Home Manager layering**: `home/common.nix` is the shared base; per-context files (`server.nix`, `desktop.nix`, `wsl.nix`, `crostini.nix`, `dev.nix`) import it and are composed per host in `flake.nix`.
- **Reusable system pieces** belong in `modules/`; host files compose modules rather than duplicating logic.
- **Secrets**: managed via Agenix in `secrets/`. `keys.nix` lists recipient public keys; `secrets.nix` maps each `.age` file to recipients. Any change to `keys.nix` requires `cd secrets && agenix --rekey`, which needs access to a private key already on the recipient list (typically the host SSH key, requiring sudo). If you can't rekey, call it out in the PR (`CLAUDE.md`).
- **Default user**: `patrick` (option `cosmo.user.default`); work identity uses `paflynn`. Identity files live in `home/identities/`.

## Gotchas
- `nixpkgs` follows `nixos-unstable`; flake input updates are automated by `.github/workflows/update-flake-lock.yml` and land via PR.
- Several flake inputs are personal repos (`patflynn/klaus`, `patflynn/github-relay`, `gunk-dev/reel-life`); flake evaluation may require network access to GitHub.
- CI dry-builds only the hosts in the matrix (`classic-laddie`, `makers-nix`, `johnny-walker`) and the four `homeConfigurations`. `weller` and `klaus-worker-0` are not exercised by `ci.yml`'s build jobs — `nix flake check` is the broader gate.
- `flake.nix.local` is gitignored (`.gitignore`) and intended for local-only overrides.
- `.pre-commit-config.yaml` at repo root is a symlink into `/nix/store/...` generated by the flake's pre-commit hook setup; do not edit it directly.
- The `.gitignore` lists many legacy top-level files/dirs (e.g. `home.nix`, `emacs/`, `i3/`, `bin/`) that are preserved locally but excluded from git — do not resurrect these paths.

## External dependencies
- GitHub (flake inputs, CI, agent workflows).
- Agenix for secret encryption/decryption (no remote service; relies on local SSH keys listed in `secrets/keys.nix`).
- Hosts referenced by name in `flake.nix`: `classic-laddie`, `johnny-walker`, `makers-nix`, `weller`, `klaus-worker-0`.
