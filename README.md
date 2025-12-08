# Cosmo

This is the central NixOS configuration repository for my infrastructure.

## Status: Fresh Start

This repository is currently in **Phase 1** of the [Roadmap](./ROADMAP.md).

## Usage

See [AGENTS.md](./AGENTS.md) for common administrative commands.

├── home/        # Home Manager configurations (User environment)
├── hosts/       # Machine-specific configurations
├── modules/     # Reusable NixOS modules
├── secrets/     # Encrypted secrets (SOPS)
├── flake.nix    # Entry point
└── ...

## Setup Guides

*   [Doom Emacs Setup](./docs/doom-emacs-setup.md): Manual steps to bootstrap Doom Emacs.
