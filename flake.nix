{
  description = "Two-host NixOS configuration with Disko, Secure Boot, and TPM2";

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
    }@inputs:
    let
      inherit (nixpkgs) lib;

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

      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = lib.genAttrs supportedSystems;
      pkgsFor = system: nixpkgs.legacyPackages.${system};

      commonModules = [
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
        name: host: extraModules:
        nixpkgs.lib.nixosSystem {
          inherit (host) system;
          specialArgs = {
            inherit inputs;
            targetHost = name;
            targetSystem = host.system;
          };
          modules =
            commonModules
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
            ++ extraModules;
        };

      nixosConfigurations = lib.concatMapAttrs (
        name: host:
        {
          "${name}" = mkHost name host [
            lanzaboote.nixosModules.lanzaboote
            ./modules/boot/secure-boot.nix
          ];
          "${name}-bootstrap" = mkHost name host [
            ./modules/boot/bootstrap.nix
          ];
        }
      ) hosts;

      mkCheck =
        system:
        name:
        {
          nativeBuildInputs,
          script,
        }:
        (pkgsFor system).runCommand name { inherit nativeBuildInputs; } ''
          cp -R ${self} source
          chmod -R u+w source
          cd source
          ${script}
          touch "$out"
        '';

      nativeHostChecks =
        system:
        builtins.listToAttrs (
          lib.concatMap (
            name:
            let
              production = nixosConfigurations.${name}.config;
              bootstrap = nixosConfigurations."${name}-bootstrap".config;
            in
            [
              {
                name = "${name}-production-system";
                value = production.system.build.toplevel;
              }
              {
                name = "${name}-bootstrap-system";
                value = bootstrap.system.build.toplevel;
              }
              {
                name = "${name}-boot-policy";
                value =
                  assert production.networking.hostName == name;
                  assert production.nixpkgs.hostPlatform.system == system;
                  assert production.boot.lanzaboote.enable;
                  assert !production.boot.loader.systemd-boot.enable;
                  assert production.boot.lanzaboote.configurationLimit == 8;
                  assert production.boot.lanzaboote.measuredBoot.pcrs == [
                    4
                    7
                  ];
                  assert bootstrap.networking.hostName == name;
                  assert bootstrap.nixpkgs.hostPlatform.system == system;
                  assert bootstrap.boot.loader.systemd-boot.enable;
                  (pkgsFor system).runCommand "${name}-boot-policy" { } ''
                    touch "$out"
                  '';
              }
            ]
          ) (builtins.filter (name: hosts.${name}.system == system) (builtins.attrNames hosts))
        );

      repositoryChecks =
        system:
        lib.optionalAttrs (system == "x86_64-linux") {
          nix-format = mkCheck system "nix-format" {
            nativeBuildInputs = [ (pkgsFor system).nixfmt ];
            script = ''
              find . -name '*.nix' -print0 | xargs -0 nixfmt --check
            '';
          };

          nix-static = mkCheck system "nix-static" {
            nativeBuildInputs = [
              (pkgsFor system).deadnix
              (pkgsFor system).statix
            ];
            script = ''
              deadnix --fail .
              statix check .
            '';
          };

          shell = mkCheck system "shell" {
            nativeBuildInputs = [ (pkgsFor system).shellcheck ];
            script = ''
              shellcheck install.sh tests/install-functions.sh
              bash -n install.sh tests/install-functions.sh
              bash tests/install-functions.sh
            '';
          };

          secrets = mkCheck system "secrets" {
            nativeBuildInputs = [ (pkgsFor system).gitleaks ];
            script = ''
              gitleaks detect --source . --no-git --redact --verbose
            '';
          };

          qml = mkCheck system "qml" {
            nativeBuildInputs = [
              (pkgsFor system).qt6.qtdeclarative
              (pkgsFor system).quickshell
            ];
            script = ''
              export QML2_IMPORT_PATH="${(pkgsFor system).quickshell}/lib/qt-6/qml"
              find dotfiles/quickshell -name '*.qml' -print0 \
                | xargs -0 -n1 qmllint
            '';
          };
        };
    in
    {
      inherit nixosConfigurations;

      apps = forAllSystems (system: {
        disko = {
          type = "app";
          program = "${disko.packages.${system}.default}/bin/disko";
        };
      });

      formatter = forAllSystems (system: (pkgsFor system).nixfmt);

      checks = forAllSystems (
        system: (nativeHostChecks system) // (repositoryChecks system)
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.deadnix
              pkgs.gitleaks
              pkgs.lefthook
              pkgs.nixfmt
              pkgs.shellcheck
              pkgs.statix
            ];
            shellHook = "lefthook install";
          };
        }
      );
    };
}
