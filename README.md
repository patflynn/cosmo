# Cosmo
[![CI Build Status](https://github.com/patflynn/cosmo/actions/workflows/ci.yml/badge.svg?branch=main&event=push)](https://github.com/patflynn/cosmo/actions/workflows/ci.yml)

This is the central NixOS configuration repository for my infrastructure.

## Status: Virtualization Host

This repository is currently in **Phase 2** of the [Roadmap](./ROADMAP.md).
The foundation (ZFS, Networking, SSH) is complete, and the focus is now on Virtualization, Secrets Management, and Automation.

## Usage

All agents MUST read AGENTS.md for mandatory workflow constraints and PR requirements before making any changes.
See [AGENTS.md](./AGENTS.md) for common administrative commands.

## Structure

* `flake.nix`: Entry point.
* `hosts/`: System configurations (NixOS).
* `home/`: User configurations (Home Manager).
* `modules/`: Reusable NixOS modules.

## Setup Guides

* [Doom Emacs Setup](./docs/doom-emacs-setup.md): Manual steps to bootstrap Doom Emacs.
* [Secrets Management](./docs/secrets-management.md): How to add, edit, and rekey encrypted secrets (Agenix).
* [Generic VM Setup](./docs/vm-setup.md): How to build and deploy NixOS VMs (e.g., `johnny-walker`).
* [Bud-Lite Setup](./docs/bud-lite-setup.md): Setup guide for the standalone Home Manager configuration on Crostini.
