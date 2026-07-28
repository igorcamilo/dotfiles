{ pkgs, plasma-manager, ... }:

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

  # Both already default to "us"; declared so the layout is recorded rather
  # than inherited. console.keyMap is what the disk-unlock prompt uses, before
  # Plasma's own layout applies.
  console.keyMap = "us";

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

    xserver.xkb.layout = "us"; # Read by Plasma; does not start an X server.

    openssh = {
      enable = true;
      # Root has no password on this machine, so the only way in is igor.
      # Add a key to users.users.igor.openssh.authorizedKeys.keys and set
      # PasswordAuthentication = false once there is one to log in with.
      settings.PermitRootLogin = "no";
    };

    printing.enable = true;

    # Discovery for network printers; CUPS finds nothing on its own here.
    avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };

    # plasma6 already provides Breeze theming, the portals, the polkit agent,
    # KWallet, BlueDevil, udisks2, dconf, and the default Wayland session.
    desktopManager.plasma6.enable = true;
    displayManager.plasma-login-manager.enable = true;

    btrfs.autoScrub.enable = true;

    # llama-server rather than Ollama because n-cpu-moe parks this MoE model's
    # coldest expert weights in system RAM; Ollama's offload is not MoE-aware.
    # Q3_K_M (14.7GB) is the largest quantization that fits 16GB next to KWin.
    # The offload and context numbers are a starting point - llama-server logs
    # its real VRAM use at startup. README.md has the VS Code wiring.
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

  # First start downloads the 14.7GB model; the default timeout would kill it.
  systemd.services.llama-cpp.serviceConfig.TimeoutStartSec = "30min";

  programs = {
    zsh.enable = true;
    steam.enable = true;
    vscode.enable = true;

    nh = {
      enable = true;
      flake = "/etc/nixos";
      clean = {
        enable = true;
        # nh keeps one generation by default. Keeping as many as Lanzaboote
        # lists in modules/boot/secure-boot.nix stops the boot menu offering
        # entries whose system closure has been collected.
        extraArgs = "--keep 8";
      };
    };

    # Extensions have to be declared here rather than in home.nix: Home
    # Manager applies policies by wrapping the Firefox package, and its
    # package is null there. Profile settings live in home.nix.
    firefox = {
      enable = true;

      # Keys are add-on ids on addons.mozilla.org. force_installed means this
      # file owns the extension: to remove one, remove it here. Plasma
      # Integration's native messaging host needs no wiring, because plasma6
      # already adds it to programs.firefox.nativeMessagingHosts.packages.
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
      # Cycles needs HIP to render on the GPU, and nixpkgs has no prebuilt
      # ROCm Blender, so this builds from source and takes hours. Select the
      # device under Settings > System > Cycles Render Devices > HIP.
      (pkgs.blender.override { rocmSupport = true; })
      pkgs.ffmpeg # H.264/AAC decoding for Firefox, which cannot bundle it.
      pkgs.git
      pkgs.godot
      pkgs.nano
      pkgs.nixfmt
      plasma-manager.packages.${pkgs.system}.rc2nix # Used by config-sync.
    ];

    # Without this, VS Code and other Electron apps fall back to XWayland.
    sessionVariables.NIXOS_OZONE_WL = "1";
  };

  # Starship's prompt needs the patched glyphs. Select it as Konsole's font.
  fonts.packages = [ pkgs.nerd-fonts.jetbrains-mono ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Compatibility version, not the Nixpkgs channel. Read the NixOS release
  # notes before changing it after installation.
  system.stateVersion = "26.05";
}
