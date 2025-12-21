{
  description = "Cosmo: Fresh Start 2025";

  inputs = {
    # The unstable branch is usually fine for desktops/home-servers,
    # but use "nixos-24.11" if you want rock-solid stability.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";
    nixos-wsl.inputs.nixpkgs.follows = "nixpkgs";

    pre-commit-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      nixos-generators,
      agenix,
      pre-commit-hooks,
      ...
    }@inputs:
    {
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-tree;
      nixosConfigurations = {
        # Hostname: classic-laddie
        classic-laddie = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            ./hosts/classic-laddie/default.nix
            agenix.nixosModules.default
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = { inherit inputs; };
              home-manager.users.patrick = import ./home/server.nix;
            }
          ];
        };

        # Hostname: wsl
        wsl = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            ./hosts/wsl/default.nix
            inputs.nixos-wsl.nixosModules.wsl
            agenix.nixosModules.default
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = { inherit inputs; };
              home-manager.users.patrick = import ./home/wsl.nix;
            }
          ];
        };
      };

      packages.x86_64-linux = { };

      checks.x86_64-linux = {
        pre-commit-check = pre-commit-hooks.lib.x86_64-linux.run {
          src = ./.;
          hooks = {
            nixfmt-rfc-style.enable = true;
            detect-private-keys.enable = true;
          };
        };
      };

      devShells.x86_64-linux.default = nixpkgs.legacyPackages.x86_64-linux.mkShell {
        inherit (self.checks.x86_64-linux.pre-commit-check) shellHook;
        buildInputs = self.checks.x86_64-linux.pre-commit-check.enabledPackages;
      };
    };
}
