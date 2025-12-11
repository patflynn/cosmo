{
  description = "Cosmo: Fresh Start 2025";

  inputs = {
    # The unstable branch is usually fine for desktops/home-servers, 
    # but use "nixos-24.11" if you want rock-solid stability.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";
    nixos-wsl.inputs.nixpkgs.follows = "nixpkgs";

    microvm.url = "github:astro/microvm.nix";
    microvm.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager, microvm, ... }@inputs: {
    nixosConfigurations = {
      # Hostname: classic-laddie
      classic-laddie = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/classic-laddie/default.nix

          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
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

          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.patrick = import ./home/wsl.nix;
          }
        ];
      };

      # Hostname: johnny-walker
      johnny-walker = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/johnny-walker/default.nix

          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.patrick = import ./home/vm.nix;
          }
        ];
      };
    };
  };
}
