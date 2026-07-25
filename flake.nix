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
        # Relative on purpose, not an absolute path: this needs to
        # resolve correctly both during install (flake root is
        # /mnt/home/igor/dotfiles) and afterwards (flake root is
        # /home/igor/dotfiles, or /etc/nixos symlinked to it) - a
        # fixed absolute path can only ever be right for one of those.
        # It's gitignored (see "Secrets") since it's machine-specific;
        # install.sh stages its path with `git add --intent-to-add`
        # so this relative import can still find it despite Nix only
        # seeing git-tracked files once this directory is a working
        # tree - see README's "Tracking changes after install".
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
