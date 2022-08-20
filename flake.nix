{
  outputs = { self, nixpkgs }: {
    # replace 'joes-desktop' with your hostname here.
    nixosConfigurations.classic-laddie = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ ./machines/classic-laddie/default.nix ];
    };
  };
}