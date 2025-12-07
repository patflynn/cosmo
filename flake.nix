{
  description = "Cosmo: Fresh Start 2025";

  inputs = {
    # The unstable branch is usually fine for desktops/home-servers, 
    # but use "nixos-24.11" if you want rock-solid stability.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs: {
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
    };
  };
}
