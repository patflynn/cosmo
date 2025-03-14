{
  description = "Patrick's NixOS configurations for multiple platforms";

  inputs = {
    # Core dependencies
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    
    nixpkgs-unfree.url = "github:numtide/nixpkgs-unfree";
    nixpkgs-unfree.inputs.nixpkgs.follows = "nixpkgs";
    
    flake-utils.url = "github:numtide/flake-utils";
    
    # Home Manager
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    # Darwin support
    darwin = {
      url = "github:lnl7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    # Additional tools
    kolide-launcher.url = "github:znewman01/kolide-launcher";
    kolide-launcher.inputs.nixpkgs.follows = "nixpkgs";
    
    emacs-overlay = { 
      url = "github:nix-community/emacs-overlay"; 
    };
    
    doom-emacs = {
      url = "github:nix-community/nix-doom-emacs";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.emacs-overlay.follows = "emacs-overlay";
    };
  };

  outputs = inputs@{ 
    self, 
    nixpkgs, 
    flake-utils, 
    home-manager, 
    darwin, 
    doom-emacs, 
    emacs-overlay, 
    kolide-launcher, 
    ... 
  }: {
    # NixOS configurations
    nixosConfigurations = {
      # Desktop configuration
      desktop = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./modules/hosts/desktop
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.patrick = import ./home/linux;
          }
          kolide-launcher.nixosModules.x86_64-linux.default
        ];
        specialArgs = inputs;
      };
      
      # Server configuration (based on nix-basic)
      server = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./modules/hosts/server
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.patrick = import ./home/linux;
          }
        ];
        specialArgs = inputs;
      };
    };
    
    # Darwin configurations for macOS
    darwinConfigurations = {
      macbook = darwin.lib.darwinSystem {
        system = "aarch64-darwin"; # For Apple Silicon, use x86_64-darwin for Intel
        modules = [
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.patrick = import ./home/darwin;
          }
        ];
        specialArgs = inputs;
      };
    };
    
    # Standalone home-manager configuration for ChromeOS
    homeConfigurations = {
      chromeos = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        modules = [
          ./home/linux
          {
            # ChromeOS-specific overrides
            home.username = "patrick";
            home.homeDirectory = "/home/patrick";
            home.stateVersion = "23.11";
          }
        ];
        extraSpecialArgs = inputs;
      };
    };
  };
}
