# CLAUDE.md - Agent Instructions for cosmo repository

## Commands

- System update: `sudo nixos-rebuild switch --flake ~/hack/cosmo --upgrade --impure`
- Test config: `sudo nixos-rebuild test --flake ~/hack/cosmo`
- Check NixOS version: `nixos-version`
- List generations: `sudo nix-env --list-generations --profile /nix/var/nix/profiles/system`
- Build for specific host: `sudo nixos-rebuild switch --flake ~/hack/cosmo#classic-laddie`

## Coding Style Guidelines

- Format: Use 2-space indentation for Nix files
- Imports: Group imports logically, keep related imports together
- Naming: Use camelCase for variables, descriptive names for functions
- Structure: Follow standard Nix module structure with inputs/outputs pattern
- Git: Use declarative commit messages, sign all commits (gitsign)
- Prefer declarative configuration over imperative changes
- Follow NixOS module system patterns and best practices
- Keep configurations modular with clear separation of concerns
- Always use the Github PR workflow without being prompted to push and generate PRs.
