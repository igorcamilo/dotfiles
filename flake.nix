{
  description = "NixOS configuration for Igor's desktop";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.1.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      disko,
      lanzaboote,
      home-manager,
      ...
    }:
    let
      sharedModules = [
        disko.nixosModules.disko
        lanzaboote.nixosModules.lanzaboote
        home-manager.nixosModules.home-manager
        ./configuration.nix
        ./modules/boot/secure-boot.nix
        ./modules/boot/splash.nix
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            users.igor = import ./home.nix;
          };
        }
      ];
    in
    {
      nixosConfigurations.igor-desktop = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = sharedModules ++ [ ./hosts/igor-desktop ];
      };

      # install.sh uses the Disko app pinned by flake.lock.
      apps.x86_64-linux.disko = {
        type = "app";
        program = "${disko.packages.x86_64-linux.default}/bin/disko";
      };
    };
}
