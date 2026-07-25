{
  description = "NixOS: disko + LUKS2/Btrfs + UKI + Secure Boot (lanzaboote) + TPM2 unlock";

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
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      commonModules = [
        disko.nixosModules.disko
        home-manager.nixosModules.home-manager
        ./hosts/igor-desktop
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            users.igor = import ./home.nix;
          };
        }
      ];

      mkHost =
        extraModules:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = commonModules ++ extraModules;
        };

      mkCheck =
        name:
        {
          nativeBuildInputs,
          script,
        }:
        pkgs.runCommand name { inherit nativeBuildInputs; } ''
          cp -R ${self} source
          chmod -R u+w source
          cd source
          ${script}
          touch "$out"
        '';
    in
    {
      nixosConfigurations = {
        igor-desktop = mkHost [
          lanzaboote.nixosModules.lanzaboote
          ./modules/boot/secure-boot.nix
        ];

        igor-desktop-bootstrap = mkHost [
          ./modules/boot/bootstrap.nix
        ];
      };

      apps.${system}.disko = {
        type = "app";
        program = "${disko.packages.${system}.default}/bin/disko";
      };

      formatter.${system} = pkgs.nixfmt;

      checks.${system} = {
        production-system = self.nixosConfigurations.igor-desktop.config.system.build.toplevel;
        bootstrap-system = self.nixosConfigurations.igor-desktop-bootstrap.config.system.build.toplevel;

        nix-format = mkCheck "nix-format" {
          nativeBuildInputs = [ pkgs.nixfmt ];
          script = ''
            find . -name '*.nix' -print0 | xargs -0 nixfmt --check
          '';
        };

        nix-static = mkCheck "nix-static" {
          nativeBuildInputs = [
            pkgs.deadnix
            pkgs.statix
          ];
          script = ''
            deadnix --fail .
            statix check .
          '';
        };

        shell = mkCheck "shell" {
          nativeBuildInputs = [ pkgs.shellcheck ];
          script = ''
            shellcheck install.sh tests/install-functions.sh
            bash -n install.sh tests/install-functions.sh
            bash tests/install-functions.sh
          '';
        };

        secrets = mkCheck "secrets" {
          nativeBuildInputs = [ pkgs.gitleaks ];
          script = ''
            gitleaks detect --source . --no-git --redact --verbose
          '';
        };

        qml = mkCheck "qml" {
          nativeBuildInputs = [
            pkgs.qt6.qtdeclarative
            pkgs.quickshell
          ];
          script = ''
            export QML2_IMPORT_PATH="${pkgs.quickshell}/lib/qt-6/qml"
            find dotfiles/quickshell -name '*.qml' -print0 \
              | xargs -0 -n1 qmllint
          '';
        };
      };

      devShells.${system}.default = pkgs.mkShell {
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
    };
}
