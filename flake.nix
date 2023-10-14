{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/master";

    nixpkgs-unfree.url = "github:numtide/nixpkgs-unfree";
    nixpkgs-unfree.inputs.nixpkgs.follows = "nixpkgs";

    flake-utils.url = "github:numtide/flake-utils";

    kolide-launcher.url = "github:znewman01/kolide-launcher";
    kolide-launcher.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    #go-tuf.url = "github.com:znewman01/go-tuf/nix";

    emacs-overlay = { url = "github:nix-community/emacs-overlay"; };

    doom-emacs = {
      url = "github:nix-community/nix-doom-emacs";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.emacs-overlay.follows = "emacs-overlay";
    };
  };

  outputs = inputs@{ nixpkgs, flake-utils, home-manager, doom-emacs, emacs-overlay, kolide-launcher, ... }: {

    nixosConfigurations.classic-laddie = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
       modules = [
        ./classic-laddie/default.nix
        home-manager.nixosModule
        kolide-launcher.nixosModules.x86_64-linux.default
      ];
      specialArgs = inputs;
    };
  };
}
