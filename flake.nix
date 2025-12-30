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
    let
      mkHome =
        {
          username,
          profile,
        }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          extraSpecialArgs = { inherit inputs; };
          modules = [
            profile
            {
              home.username = username;
              home.homeDirectory = "/home/${username}";
            }
          ];
        };
    in
    {
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-tree;

      nixosConfigurations = {
        # Hostname: classic-laddie
        classic-laddie =
          let
            system = "x86_64-linux";
            config = nixpkgs.lib.nixosSystem {
              inherit system;
              specialArgs = { inherit inputs; };
              modules = [ ./hosts/classic-laddie/default.nix ];
            };
          in
          nixpkgs.lib.nixosSystem {
            inherit system;
            specialArgs = { inherit inputs; };
            modules = [
              ./hosts/classic-laddie/default.nix
              agenix.nixosModules.default
              home-manager.nixosModules.home-manager
              {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.extraSpecialArgs = {
                  inherit inputs;
                  nixosConfig = config.config;
                };
                home-manager.users.patrick = import ./home/workstation.nix;
              }
            ];
          };

        # Hostname: makers-nix
        makers-nix =
          let
            system = "x86_64-linux";
            config = nixpkgs.lib.nixosSystem {
              inherit system;
              specialArgs = { inherit inputs; };
              modules = [ ./hosts/makers-nix/default.nix ];
            };
          in
          nixpkgs.lib.nixosSystem {
            inherit system;
            specialArgs = { inherit inputs; };
            modules = [
              ./hosts/makers-nix/default.nix
              inputs.nixos-wsl.nixosModules.wsl
              agenix.nixosModules.default
              home-manager.nixosModules.home-manager
              {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.extraSpecialArgs = {
                  inherit inputs;
                  nixosConfig = config.config;
                };
                home-manager.users.patrick = import ./home/wsl.nix;
              }
            ];
          };

        # Hostname: johnny-walker
        johnny-walker =
          let
            system = "x86_64-linux";
            config = nixpkgs.lib.nixosSystem {
              inherit system;
              specialArgs = { inherit inputs; };
              modules = [ ./hosts/johnny-walker/default.nix ];
            };
          in
          nixpkgs.lib.nixosSystem {
            inherit system;
            specialArgs = { inherit inputs; };
            modules = [
              ./hosts/johnny-walker/default.nix
              agenix.nixosModules.default
              home-manager.nixosModules.home-manager
              {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.extraSpecialArgs = {
                  inherit inputs;
                  nixosConfig = config.config;
                };
                home-manager.users.patrick = import ./home/workstation.nix;
              }
            ];
          };
      };

      homeConfigurations = {
        "patrick@debian" = mkHome {
          username = "patrick";
          profile = ./home/linux.nix;
        };
        "patrick@crostini" = mkHome {
          username = "patrick";
          profile = ./home/crostini.nix;
        };

        # Default configuration for the current user
        default = mkHome {
          username =
            let
              user = builtins.getEnv "USER";
            in
            if user == "" then "patrick" else user;
          profile = ./home/linux.nix;
        };
      };

      packages.x86_64-linux = {
        # Expose zizmor here so CI can run it via 'nix run .#zizmor'
        # to avoid registry lookups and devShell hooks.
        zizmor = nixpkgs.legacyPackages.x86_64-linux.zizmor;
        johnny-walker-image = nixos-generators.nixosGenerate {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            ./hosts/johnny-walker/default.nix
            agenix.nixosModules.default
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = { inherit inputs; };
              home-manager.users.patrick = import ./home/workstation.nix;
            }
          ];
          format = "qcow";
        };
      };

      checks.x86_64-linux = {
        pre-commit-check = pre-commit-hooks.lib.x86_64-linux.run {
          src = ./.;
          hooks = {
            nixfmt-rfc-style.enable = true;
            detect-private-keys.enable = true;
            zizmor = {
              enable = true;
              name = "zizmor";
              entry = "${nixpkgs.legacyPackages.x86_64-linux.zizmor}/bin/zizmor .";
              pass_filenames = false;
            };
          };
        };
      };

      devShells.x86_64-linux.default = nixpkgs.legacyPackages.x86_64-linux.mkShell {
        inherit (self.checks.x86_64-linux.pre-commit-check) shellHook;
        buildInputs = self.checks.x86_64-linux.pre-commit-check.enabledPackages;
      };
    };
}
