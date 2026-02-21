# Managed hosts: classic-laddie, johnny-walker, makers-nix, weller
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

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    klaus = {
      url = "github:patflynn/klaus";
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
      klaus,
      ...
    }@inputs:
    let
      mkHome =
        {
          username,
          identity,
          baseModule,
          homeDirectory ? "/home/${username}",
        }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            system = "x86_64-linux";
            config.allowUnfree = true;
          };
          extraSpecialArgs = { inherit inputs; };
          modules = [
            baseModule
            identity
            {
              home.username = username;
              home.homeDirectory = homeDirectory;
            }
          ];
        };

      mkBootstrap =
        {
          system ? "x86_64-linux",
          hardware,
          disk ? null,
          hostName ? "nixos-bootstrap",
          hostId ? null,
          user ? "patrick",
          email ? "big.pat@gmail.com",
        }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [
            hardware
            (if disk != null then disk else { })
            (if disk != null then inputs.disko.nixosModules.disko else { })
            ./modules/bootstrap.nix
            {
              networking.hostName = hostName;
              cosmo.user.default = user;
              cosmo.user.email = email;
            }
            (if hostId != null then { networking.hostId = hostId; } else { })
          ];
        };
    in
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
            (
              { config, ... }:
              {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.backupFileExtension = "backup";
                home-manager.extraSpecialArgs = { inherit inputs; };
                home-manager.users.${config.cosmo.user.default} = {
                  imports = [
                    ./home/workstation.nix
                    ./home/remoting.nix
                    ./home/identities/personal.nix
                  ];
                };
              }
            )
          ];
        };

        # Hostname: classic-laddie-bootstrap
        classic-laddie-bootstrap = mkBootstrap {
          hardware = ./hosts/classic-laddie/hardware.nix;
          hostName = "classic-laddie-bootstrap";
          hostId = "8425e349";
        };

        # Hostname: makers-nix
        makers-nix = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            ./hosts/makers-nix/default.nix
            inputs.nixos-wsl.nixosModules.wsl
            agenix.nixosModules.default
            home-manager.nixosModules.home-manager
            (
              { config, ... }:
              {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.backupFileExtension = "backup";
                home-manager.extraSpecialArgs = { inherit inputs; };
                home-manager.users.${config.cosmo.user.default} = {
                  imports = [
                    ./home/wsl.nix
                    ./home/identities/personal.nix
                  ];
                };
              }
            )
          ];
        };

        # Hostname: johnny-walker
        johnny-walker = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            ./hosts/johnny-walker/default.nix
            agenix.nixosModules.default
            home-manager.nixosModules.home-manager
            (
              { config, ... }:
              {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.backupFileExtension = "backup";
                home-manager.extraSpecialArgs = { inherit inputs; };
                home-manager.users.${config.cosmo.user.default} = {
                  imports = [
                    ./home/workstation.nix
                    ./home/identities/personal.nix
                  ];
                };
              }
            )
          ];
        };

        # Hostname: weller-bootstrap (Initial install target)
        weller-bootstrap = mkBootstrap {
          hardware = ./hosts/weller/hardware.nix;
          disk = ./hosts/weller/disk-config.nix;
          hostName = "weller-bootstrap";
        };

        # Hostname: weller (dual-boot Windows 11 + NixOS workstation)
        weller = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            ./hosts/weller/default.nix
            ./hosts/weller/disk-config.nix
            inputs.disko.nixosModules.disko
            agenix.nixosModules.default
            home-manager.nixosModules.home-manager
            (
              { config, ... }:
              {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.backupFileExtension = "backup";
                home-manager.extraSpecialArgs = { inherit inputs; };
                home-manager.users.${config.cosmo.user.default} = {
                  imports = [
                    ./home/workstation.nix
                    ./home/identities/personal.nix
                  ];
                };
              }
            )
          ];
        };
      };

      homeConfigurations = {
        # 1. Personal Debian (The classic)
        "personal" = mkHome {
          username = "patrick";
          identity = ./home/identities/personal.nix;
          baseModule = ./home/linux.nix;
        };

        # 2. Work Debian (The new pure target)
        "paflynn@bushmills" = mkHome {
          username = "paflynn";
          identity = ./home/identities/work.nix;
          baseModule = ./home/linux.nix;
          homeDirectory = "/usr/local/google/home/paflynn";
        };

        # 3. Personal Crostini
        "crostini" = mkHome {
          username = "patrick";
          identity = ./home/identities/personal.nix;
          baseModule = ./home/crostini.nix;
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
            (
              { config, ... }:
              {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.backupFileExtension = "backup";
                home-manager.extraSpecialArgs = { inherit inputs; };
                home-manager.users.${config.cosmo.user.default} = {
                  imports = [
                    ./home/workstation.nix
                    ./home/identities/personal.nix
                  ];
                };
              }
            )
          ];
          format = "qcow";
        };
      };

      checks.x86_64-linux = {
        pre-commit-check = pre-commit-hooks.lib.x86_64-linux.run {
          src = ./.;
          hooks = {
            nixfmt.enable = true;
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

      devShells.x86_64-linux.default =
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
        in
        pkgs.mkShell {
          inherit (self.checks.x86_64-linux.pre-commit-check) shellHook;
          buildInputs = self.checks.x86_64-linux.pre-commit-check.enabledPackages;
        };
    };
}
