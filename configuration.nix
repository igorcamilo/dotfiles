{ config, lib, pkgs, inputs, ... }:

{
  networking.hostName = "igor-desktop";
  networking.networkmanager.enable = true;
  time.timeZone = "Europe/Berlin";

  # English UI, German formatting for the rest. See README for a known
  # glibc/CLDR gap that can affect this combination.
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "de_DE.UTF-8";
    LC_IDENTIFICATION = "de_DE.UTF-8";
    LC_MEASUREMENT = "de_DE.UTF-8";
    LC_MONETARY = "de_DE.UTF-8";
    LC_NAME = "de_DE.UTF-8";
    LC_NUMERIC = "de_DE.UTF-8";
    LC_PAPER = "de_DE.UTF-8";
    LC_TELEPHONE = "de_DE.UTF-8";
    LC_TIME = "de_DE.UTF-8";
  };

  nixpkgs.config.allowUnfree = true;

  # Boot: UKI + Secure Boot via lanzaboote, replacing systemd-boot.
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
    configurationLimit = 8;
    measuredBoot = {
      enable = true;
      pcrs = [ 4 7 ];
    };
  };
  boot.initrd.systemd.enable = true; # required for TPM2 auto-unlock

  # Default Wi-Fi backend (wpa_supplicant) is used here. See README for
  # the iwd backend tradeoffs before uncommenting:
  # networking.networkmanager.wifi.backend = "iwd";

  users.users.igor = {
    isNormalUser = true;
    description = "Igor Camilo";
    extraGroups = [ "wheel" "networkmanager" ];
    # Password is not set here; see secrets.nix and README.md.
  };

  zramSwap.enable = true;

  # Desktop: Hyprland, with Quickshell as the shell layer (bar, wallpaper,
  # lock screen). Wallpaper is drawn by Quickshell itself (a background
  # layer-shell surface), so no separate wallpaper daemon is installed.
  programs.hyprland.enable = true;
  environment.systemPackages = with pkgs; [
    quickshell
    matugen
  ];
  qt.enable = true;
  programs.dconf.enable = true;

  # greetd runs a throwaway Hyprland+Quickshell "greeter" session (see
  # dotfiles/hypr/greeter.conf and dotfiles/quickshell/greeter) that
  # authenticates over greetd's own IPC protocol, then hands off to the
  # user's normal session below. The greeter runs as its own system
  # user (created automatically by this module), so its files are
  # published system-wide via environment.etc rather than home-manager.
  environment.etc."greetd/hyprland.conf".source = ./dotfiles/hypr/greeter.conf;
  environment.etc."greetd/quickshell".source = ./dotfiles/quickshell/greeter;
  environment.etc."greetd/shared".source = ./dotfiles/quickshell/shared;
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "Hyprland --config /etc/greetd/hyprland.conf";
      user = "greeter";
    };
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Not the update channel (that is nixpkgs.url in flake.nix). See
  # README.md before changing this value.
  system.stateVersion = "26.05";
}
