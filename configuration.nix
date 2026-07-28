{
  lib,
  pkgs,
  plasma-manager,
  ...
}:

{
  networking.networkmanager.enable = true;
  time.timeZone = "Europe/Berlin";

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

  console.keyMap = "us"; # Already the default; declared so it is recorded.

  nixpkgs.config.allowUnfree = true;

  # RDNA4 (RX 9070 XT) needs a newer kernel than the nixpkgs default targets.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  users.users.igor = {
    isNormalUser = true;
    description = "Igor Camilo";
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
    shell = pkgs.zsh;
  };

  zramSwap.enable = true;

  hardware = {
    enableRedistributableFirmware = true;
    graphics = {
      enable = true;
      enable32Bit = true; # Steam and other 32-bit apps.
    };
    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
  };

  security.rtkit.enable = true; # Realtime scheduling for PipeWire.

  services = {
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };

    fwupd.enable = true;

    xserver.xkb.layout = "us"; # Does not start an X server.

    openssh = {
      enable = true;
      # Password login stays on until there is a key to log in with.
      settings.PermitRootLogin = "no";
    };

    printing.enable = true;
    avahi = {
      enable = true; # Network printer discovery for CUPS.
      nssmdns4 = true;
      openFirewall = true;
    };

    # plasma6 already provides Breeze theming, the portals, the polkit agent,
    # KWallet, BlueDevil, udisks2, dconf, and the default Wayland session.
    desktopManager.plasma6.enable = true;
    displayManager.plasma-login-manager.enable = true;

    btrfs.autoScrub.enable = true;

    # Not Ollama: its offload is not MoE-aware, while n-cpu-moe parks this
    # model's coldest experts in system RAM. Q3_K_M (14.7GB) is the largest
    # quantization fitting 16GB. The offload numbers are a guess, not measured.
    llama-cpp = {
      enable = true;
      package = pkgs.llama-cpp-rocm;
      settings = {
        "hf-repo" = "unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF:Q3_K_M";
        alias = "qwen3-coder-30b-a3b";
        "n-gpu-layers" = 999;
        "n-cpu-moe" = 8;
        "ctx-size" = 32768;
        jinja = true;
        "flash-attn" = "auto";
      };
    };
  };

  systemd.services.llama-cpp = {
    # Started by hand: the model holds the card's VRAM for as long as it runs.
    wantedBy = lib.mkForce [ ];
    serviceConfig.TimeoutStartSec = "30min"; # First start downloads 14.7GB.
  };

  programs = {
    zsh.enable = true;
    steam.enable = true;
    vscode.enable = true;

    nh = {
      enable = true;
      flake = "/etc/nixos";
      clean = {
        enable = true;
        # Below configurationLimit, the boot menu offers collected closures.
        extraArgs = "--keep 8";
      };
    };

    firefox = {
      enable = true;
      # Not movable to home.nix: policies are applied by wrapping the package,
      # which is null there. plasma6 supplies the Plasma native messaging host.
      policies.ExtensionSettings = {
        "{446900e4-71c2-419f-a6a7-df9c091e268b}" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/bitwarden-password-manager/latest.xpi";
          installation_mode = "force_installed";
        };
        "plasma-browser-integration@kde.org" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/plasma-integration/latest.xpi";
          installation_mode = "force_installed";
        };
      };
    };
  };

  environment = {
    systemPackages = [
      pkgs.bitwarden-desktop
      # Cached, so Cycles renders on the CPU. Eevee and the viewport use the
      # GPU either way. rocmSupport = true adds Cycles-on-GPU at the cost of a
      # source build on every update, since nothing prebuilds it.
      pkgs.blender
      pkgs.ffmpeg # Firefox loads it for H.264/AAC; it cannot bundle them.
      pkgs.git
      pkgs.godot
      pkgs.nano
      pkgs.nixfmt
      plasma-manager.packages.${pkgs.system}.rc2nix
    ];

    # Without this, Electron apps fall back to XWayland.
    sessionVariables.NIXOS_OZONE_WL = "1";
  };

  fonts.packages = [ pkgs.nerd-fonts.jetbrains-mono ]; # Starship's glyphs.

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Compatibility version, not the Nixpkgs channel. Read the NixOS release
  # notes before changing it after installation.
  system.stateVersion = "26.05";
}
