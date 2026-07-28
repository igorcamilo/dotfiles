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

  # RDNA4 (RX 9070 XT) needs a newer kernel and Mesa than the nixpkgs default
  # kernel targets; track the latest stable release instead of the default.
  boot.kernelPackages = pkgs.linuxPackages_latest;

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

  security.rtkit.enable = true; # Realtime scheduling for PipeWire.

  services = {
    # PipeWire is the current NixOS-recommended audio server, replacing both
    # PulseAudio and JACK.
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };

    # Pairing UI and polkit rules for the Bluetooth radio enabled above.
    blueman.enable = true;

    fwupd.enable = true;

    # agreety, greetd's own bundled text greeter, replaces a custom
    # Hyprland+Quickshell greeter session while Hyprland itself is still
    # being brought up on real hardware. On successful login it hands off
    # to the user's Hyprland session below via start-hyprland, the same
    # target the custom greeter used.
    greetd = {
      enable = true;
      useTextGreeter = true;
      settings.default_session.command = "${pkgs.greetd}/bin/agreety --cmd start-hyprland";
    };

    udisks2.enable = true;

    btrfs.autoScrub.enable = true;
  };

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
    # Shorter, friendlier front-end for nixos-rebuild (build-tree progress,
    # a diff of the generation change); flake points it at this checkout so
    # `nh os switch` needs no other arguments.
    nh = {
      enable = true;
      flake = "/etc/nixos";
    };
  };
  # adwaita-dark (a Qt-native reimplementation of the look) covered general
  # widget colors and menus, but not the separate Base/View palette role list
  # and icon views use (Dolphin's file grid stayed white). gtk2 as both style
  # and platformTheme instead proxies GTK's own rendering directly, so it
  # inherits the adw-gtk3-dark GTK theme in home.nix - already configured,
  # already correct for Firefox - role for role instead of approximating it.
  qt = {
    enable = true;
    platformTheme = "gtk2";
    style = "gtk2";
  };

  # programs.hyprland adds xdg-desktop-portal-hyprland and ships its own
  # hyprland-portals.conf (default = hyprland, then gtk). That file lives in
  # the package's own store path, so the override below at a higher-priority
  # /etc path is needed to route FileChooser to Dolphin's KDE portal instead.
  xdg.portal = {
    extraPortals = [ pkgs.kdePackages.xdg-desktop-portal-kde ];
    config.hyprland = {
      default = [
        "hyprland"
        "gtk"
      ];
      "org.freedesktop.impl.portal.FileChooser" = [ "kde" ];
    };
  };

  # GUI privilege prompts (mounting a drive, some NetworkManager actions)
  # need an authentication agent; home.nix installs Hyprland's own
  # (hyprpolkitagent) and hyprland.lua starts it.
  security.polkit.enable = true;

  environment = {
    systemPackages = [
      pkgs.git
      # The installed checkout contains LFS-tracked wallpapers.
      pkgs.git-lfs
      pkgs.nano
      pkgs.quickshell
    ];
    etc = {
      # Also read directly by the lock screen; see dotfiles/quickshell/lockscreen.
      "wallpaper.jpg".source = ./wallpapers/weic2216b.jpg;
    };
  };

  # JetBrainsMono Nerd Font: patched with the icon glyphs Starship's prompt
  # and Ghostty's own UI expect (see home.nix). Installed system-wide, not
  # just for igor, since fontconfig discovery works the same either way.
  fonts.packages = [ pkgs.nerd-fonts.jetbrains-mono ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Compatibility version, not the Nixpkgs update channel. Do not change it
  # after installation without reading the NixOS release notes.
  system.stateVersion = "26.05";
}
