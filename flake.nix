{
  description = "NixOS configuration for Igor's machines";

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

    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
  };

  outputs =
    {
      nixpkgs,
      disko,
      lanzaboote,
      home-manager,
      plasma-manager,
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
            sharedModules = [ plasma-manager.homeModules.plasma-manager ];
            users.igor = import ./home.nix;
            # Otherwise activation aborts on a pre-existing unmanaged file.
            backupFileExtension = "backup";
          };
        }
      ];
    in
    {
      nixosConfigurations.igor-desktop = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit plasma-manager; };
        modules = sharedModules ++ [ ./hosts/igor-desktop ];
      };

      # Keeps the tool on the revision locked here rather than a separate fetch.
      apps.x86_64-linux.disko = {
        type = "app";
        program = "${disko.packages.x86_64-linux.default}/bin/disko";
      };
    };
}
