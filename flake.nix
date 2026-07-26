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
      self,
      nixpkgs,
      disko,
      lanzaboote,
      home-manager,
      ...
    }:
    let
      inherit (nixpkgs) lib;

      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forEachSystem = lib.genAttrs systems;
      pkgsFor = system: nixpkgs.legacyPackages.${system};

      # The only machine registry in the repository.
      hosts = {
        igor-desktop = {
          system = "x86_64-linux";
          module = ./hosts/igor-desktop;
        };
        igor-vm = {
          system = "aarch64-linux";
          module = ./hosts/igor-vm;
        };
      };

      sharedModules = [
        disko.nixosModules.disko
        home-manager.nixosModules.home-manager
        ./configuration.nix
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            users.igor = import ./home.nix;
          };
        }
      ];

      mkHost =
        name: bootModules:
        let
          host = hosts.${name};
        in
        lib.nixosSystem {
          system = host.system;
          modules =
            sharedModules
            ++ [
              host.module
              (
                { config, ... }:
                {
                  nixpkgs.hostPlatform = lib.mkDefault host.system;
                  assertions = [
                    {
                      assertion = config.networking.hostName == name;
                      message = "Host ${name} must set networking.hostName to ${name}.";
                    }
                    {
                      assertion = config.nixpkgs.hostPlatform.system == host.system;
                      message = "Host ${name} must use ${host.system}.";
                    }
                  ];
                }
              )
            ]
            ++ bootModules;
        };

      # These four names are the public installation and rebuild interface.
      nixosConfigurations = {
        igor-desktop = mkHost "igor-desktop" [
          lanzaboote.nixosModules.lanzaboote
          ./modules/boot/secure-boot.nix
        ];
        igor-desktop-bootstrap = mkHost "igor-desktop" [
          ./modules/boot/bootstrap.nix
        ];
        igor-vm = mkHost "igor-vm" [
          lanzaboote.nixosModules.lanzaboote
          ./modules/boot/secure-boot.nix
        ];
        igor-vm-bootstrap = mkHost "igor-vm" [
          ./modules/boot/bootstrap.nix
        ];
      };

      mkHostChecks =
        name:
        let
          host = hosts.${name};
          pkgs = pkgsFor host.system;
          production = nixosConfigurations.${name}.config;
          bootstrap = nixosConfigurations."${name}-bootstrap".config;
        in
        {
          "${name}-production-system" = production.system.build.toplevel;
          "${name}-bootstrap-system" = bootstrap.system.build.toplevel;
          "${name}-boot-policy" =
            assert production.networking.hostName == name;
            assert production.nixpkgs.hostPlatform.system == host.system;
            assert production.boot.lanzaboote.enable;
            assert !production.boot.loader.systemd-boot.enable;
            assert production.boot.lanzaboote.configurationLimit == 8;
            assert
              production.boot.lanzaboote.measuredBoot.pcrs == [
                4
                7
              ];
            assert bootstrap.networking.hostName == name;
            assert bootstrap.nixpkgs.hostPlatform.system == host.system;
            assert bootstrap.boot.loader.systemd-boot.enable;
            pkgs.runCommand "${name}-boot-policy" { } ''
              touch "$out"
            '';
        };

      checkPackages =
        pkgs: [
          pkgs.bash
          pkgs.deadnix
          pkgs.gitleaks
          pkgs.nixfmt
          pkgs.qt6.qtdeclarative
          pkgs.quickshell
          pkgs.shellcheck
          pkgs.statix
        ];

      repositoryCheck =
        let
          pkgs = pkgsFor "x86_64-linux";
        in
        pkgs.runCommand "repository-quality"
          {
            nativeBuildInputs = checkPackages pkgs;
            QML2_IMPORT_PATH = "${pkgs.quickshell}/lib/qt-6/qml";
          }
          ''
            cp -R ${self} source
            chmod -R u+w source
            cd source
            ${pkgs.bash}/bin/bash scripts/check.sh
            touch "$out"
          '';
    in
    {
      inherit nixosConfigurations;

      checks = {
        x86_64-linux = mkHostChecks "igor-desktop" // {
          repository-quality = repositoryCheck;
        };
        aarch64-linux = mkHostChecks "igor-vm";
      };

      # install.sh uses the Disko app pinned by flake.lock.
      apps = forEachSystem (system: {
        disko = {
          type = "app";
          program = "${disko.packages.${system}.default}/bin/disko";
        };
      });

      formatter = forEachSystem (system: (pkgsFor system).nixfmt);

      devShells = forEachSystem (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          default = pkgs.mkShell {
            packages = checkPackages pkgs ++ [ pkgs.lefthook ];
            QML2_IMPORT_PATH = "${pkgs.quickshell}/lib/qt-6/qml";
          };
        }
      );
    };
}
