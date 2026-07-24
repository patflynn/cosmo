# Nixpkgs overlays applied everywhere cosmo builds packages: the standalone
# homeConfigurations (via mkHome's `import nixpkgs`) and every NixOS host (via
# `nixpkgs.overlays` in modules/common/system.nix). Keep both wiring points in
# sync when adding an overlay here.
[
  (import ./claude-code.nix)
]
