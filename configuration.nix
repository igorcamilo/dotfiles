{ pkgs, ... }:

{
  networking.networkmanager.enable = true;
  time.timeZone = "Europe/Berlin";

  # English interface text with German regional formatting.
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

  users.users.igor = {
    isNormalUser = true;
    description = "Igor Camilo";
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
    # The installer sets the initial password imperatively. Passwords remain
    # mutable, so later changes with passwd survive rebuilds.
  };

  zramSwap.enable = true;

  # Desktop: Hyprland, with Quickshell as the shell layer (bar, wallpaper,
  # lock screen). Wallpaper is drawn by Quickshell itself (a background
  # layer-shell surface), so no separate wallpaper daemon is installed.
  programs.hyprland.enable = true;
  qt.enable = true;
  programs.dconf.enable = true;

  # greetd runs a throwaway Hyprland+Quickshell "greeter" session (see
  # dotfiles/hypr/greeter.conf and dotfiles/quickshell/greeter) that
  # authenticates over greetd's own IPC protocol, then hands off to the
  # user's normal session below. The greeter runs as its own system
  # user (created automatically by this module), so its files are
  # published system-wide via environment.etc rather than home-manager.
  environment = {
    systemPackages = [ pkgs.quickshell ];
    etc = {
      "greetd/hyprland.conf".source = ./dotfiles/hypr/greeter.conf;
      "greetd/quickshell".source = ./dotfiles/quickshell/greeter;
      "greetd/shared".source = ./dotfiles/quickshell/shared;
    };
  };

  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "Hyprland --config /etc/greetd/hyprland.conf";
      user = "greeter";
    };
  };

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Compatibility version, not the Nixpkgs update channel. Do not change it
  # after installation without reading the NixOS release notes.
  system.stateVersion = "26.05";
}
