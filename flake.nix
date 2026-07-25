{
  description = "NixOS: disko + LUKS2/Btrfs + UKI + Secure Boot (lanzaboote) + TPM2 unlock";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, disko, lanzaboote, home-manager, ... }@inputs: {
    nixosConfigurations.igor-desktop = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        disko.nixosModules.disko
        lanzaboote.nixosModules.lanzaboote
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.igor = import ./home.nix;
        }
        ./disko-config.nix
        ./configuration.nix
        ./secrets.nix
        ./hardware-configuration.nix
      ];
    };

    # Development shell for working on this repository itself: provides
    # secret scanning, unrelated to the system configuration it produces.
    devShells.x86_64-linux.default =
      let pkgs = nixpkgs.legacyPackages.x86_64-linux;
      in pkgs.mkShell {
        packages = [ pkgs.gitleaks pkgs.lefthook ];
        shellHook = ''
          lefthook install
        '';
      };
  };
}
