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
            # Activation otherwise aborts the first time a home.file/programs.*
            # target already exists as a real, non-Home-Manager-owned file
            # (e.g. VS Code's own settings.json and argv.json, written before
            # home.nix declared them). This renames the collision aside
            # (settings.json -> settings.json.backup) instead of failing.
            backupFileExtension = "backup";
          };
        }
      ];
    in
    {
      nixosConfigurations.igor-desktop = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = sharedModules ++ [ ./hosts/igor-desktop ];
      };

      # Partitioning during installation runs this Disko rather than a
      # separately fetched one, so the command-line tool always matches the
      # Disko module revision recorded in flake.lock.
      apps.x86_64-linux.disko = {
        type = "app";
        program = "${disko.packages.x86_64-linux.default}/bin/disko";
      };
    };
}
