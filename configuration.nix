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
    shell = pkgs.zsh;
    # The installer sets the initial password imperatively. Passwords remain
    # mutable, so later changes with passwd survive rebuilds.
  };

  zramSwap.enable = true;

  # AMD GPU: Mesa provides RADV (Vulkan) and RadeonSI (OpenGL) for Hyprland's
  # rendering, and the redistributable firmware carries the microcode the
  # amdgpu kernel driver loads for display and video decode/encode.
  hardware = {
    enableRedistributableFirmware = true;
    graphics = {
      enable = true;
      enable32Bit = true; # Steam and other 32-bit apps need these too.
    };
    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
  };

  # PipeWire is the current NixOS-recommended audio server, replacing both
  # PulseAudio and JACK.
  security.rtkit.enable = true; # Realtime scheduling for PipeWire.
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Pairing UI and polkit rules for the Bluetooth radio enabled above.
  services.blueman.enable = true;

  services.fwupd.enable = true;

  # Desktop: Hyprland, with Quickshell as the shell layer (bar, wallpaper,
  # lock screen). Wallpaper is drawn by Quickshell itself (a background
  # layer-shell surface), so no separate wallpaper daemon is installed.
  programs = {
    hyprland.enable = true;
    dconf.enable = true;
    # Registers zsh as a valid login shell; users.users.igor.shell above
    # is what makes it igor's actual default.
    zsh.enable = true;
    # Needs the 32-bit graphics support enabled above.
    steam.enable = true;
  };
  # qt5ct/qt6ct (platformTheme) is the standard way to theme Qt apps outside
  # a running KDE Plasma session; Kvantum (style) is the engine that actually
  # renders the theme qt5ct/qt6ct picks. home.nix carries the GTK3/4 side.
  qt = {
    enable = true;
    platformTheme = "qt5ct";
    style = "kvantum";
  };

  # xdg-desktop-portal-hyprland (added automatically by programs.hyprland
  # above) only covers Screenshot/ScreenCast. Dolphin's own portal fills in
  # FileChooser and other KDE-flavored requests.
  xdg.portal.extraPortals = [ pkgs.kdePackages.xdg-desktop-portal-kde ];

  # GUI privilege prompts (mounting a drive, some NetworkManager actions)
  # need an authentication agent; home.nix installs Hyprland's own
  # (hyprpolkitagent) and hyprland.conf starts it.
  security.polkit.enable = true;

  # greetd runs a throwaway Hyprland+Quickshell "greeter" session (see
  # dotfiles/hypr/greeter.conf and dotfiles/quickshell/greeter) that
  # authenticates over greetd's own IPC protocol, then hands off to the
  # user's normal session below. The greeter runs as its own system
  # user (created automatically by this module), so its files are
  # published system-wide via environment.etc rather than home-manager.
  environment = {
    systemPackages = [
      pkgs.git
      # The installed checkout contains LFS-tracked wallpapers.
      pkgs.git-lfs
      pkgs.nano
      pkgs.quickshell
    ];
    etc = {
      "wallpaper.jpg".source = ./wallpapers/weic2216b.jpg;
      "greetd/hyprland.conf".source = ./dotfiles/hypr/greeter.conf;
      # Keep the greeter and its ../shared QML import in one Nix store tree.
      "greetd/quickshell".source = ./dotfiles/quickshell;
    };
  };

  # JetBrainsMono Nerd Font: patched with the icon glyphs Starship's prompt
  # and Ghostty's own UI expect (see home.nix). Installed system-wide, not
  # just for igor, since fontconfig discovery works the same either way.
  fonts.packages = [ pkgs.nerd-fonts.jetbrains-mono ];

  services.greetd = {
    enable = true;
    settings.default_session = {
      # Preserve compositor and greeter output after their runtime directory
      # disappears. Read it with: journalctl -b -t greetd-greeter
      command = "${pkgs.systemd}/bin/systemd-cat --identifier=greetd-greeter -- start-hyprland -- --config /etc/greetd/hyprland.conf";
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
