{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/master";

    nixpkgs-unfree.url = "github:numtide/nixpkgs-unfree";
    nixpkgs-unfree.inputs.nixpkgs.follows = "nixpkgs";

    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = inputs@{ nixpkgs, flake-utils, ... }: {

    nixosConfigurations.classic-laddie = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ ./machines/classic-laddie/default.nix ];
    };
  };
}