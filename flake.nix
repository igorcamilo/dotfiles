{
  description = "NixOS configuration for Igor's desktop and ARM virtual machine";

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

      mkHost =
        system: hostModule:
        nixpkgs.lib.nixosSystem {
          inherit system;
          modules = sharedModules ++ [ hostModule ];
        };
    in
    {
      nixosConfigurations = {
        igor-desktop = mkHost "x86_64-linux" ./hosts/igor-desktop;
        igor-vm = mkHost "aarch64-linux" ./hosts/igor-vm;
      };

      # install.sh uses the Disko app pinned by flake.lock.
      apps = {
        x86_64-linux.disko = {
          type = "app";
          program = "${disko.packages.x86_64-linux.default}/bin/disko";
        };
        aarch64-linux.disko = {
          type = "app";
          program = "${disko.packages.aarch64-linux.default}/bin/disko";
        };
      };
    };
}
