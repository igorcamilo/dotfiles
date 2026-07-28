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
    # Installation sets the initial password with passwd. Passwords remain
    # mutable, so later changes survive rebuilds.
  };

  zramSwap.enable = true;

  # AMD GPU: Mesa provides RADV (Vulkan) and RadeonSI (OpenGL) for KWin's
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

    fwupd.enable = true;

    # Plasma 6 on Wayland, with KDE's own login manager instead of SDDM. The
    # plasma6 module already brings Breeze theming for Qt and GTK, the
    # portals, the polkit agent, KWallet, BlueDevil for the Bluetooth radio
    # enabled above, udisks2, dconf, and it makes the Wayland "plasma" session
    # the default one, so none of that needs declaring here.
    desktopManager.plasma6.enable = true;
    displayManager.plasma-login-manager.enable = true;

    btrfs.autoScrub.enable = true;

    # Runs Qwen3-Coder-30B-A3B (a mixture-of-experts model: 30B total
    # parameters, ~3B active per token) through llama.cpp's own llama-server
    # rather than Ollama, whose offload logic is not MoE-aware. llama-server's
    # n-cpu-moe setting deliberately parks the coldest expert weights in
    # system RAM and pulls back only the ones a token actually routes to,
    # which is what buys a real context window on top of a model this size.
    #
    # Q3_K_M (14.7GB) is the quantization that fits this card's 16GB alongside
    # the desktop's own VRAM usage; Q4_K_M alone is 18.6GB. hf-repo pulls that
    # GGUF straight from its source on first start and caches it under
    # /var/cache/llama-cpp (the module sets LLAMA_CACHE there), so restarts do
    # not re-download it. ROCm 7.2 added official support for this GPU
    # (RDNA4/gfx1201), so rocmOverrideGfx is only a fallback if a future
    # package update fails to detect it.
    #
    # n-gpu-layers/n-cpu-moe/ctx-size are a starting point, not tuned numbers:
    # llama-server logs its actual VRAM allocation at startup, and both
    # offload settings want adjusting from there until the model fits next to
    # KWin's own VRAM draw. flash-attn = "auto" falls back safely if
    # ROCm/gfx1201 flash-attention support is flaky on the ROCm point release
    # in use, instead of hard-failing.
    #
    # VS Code integration is manual: run "Chat: Manage Language Models" ->
    # Add Models -> Custom Endpoint -> Chat Completions, URL
    # http://127.0.0.1:8080/v1/chat/completions, model id
    # "qwen3-coder-30b-a3b" (the alias below). Set "toolCalling": true on that
    # model in the chatLanguageModels.json VS Code opens for you - without it
    # Copilot only offers this model in Ask mode, not Agent mode. Known
    # caveat: the chat template embedded in this GGUF 500s on tool calls whose
    # parameters have no "properties" field; the community patch is a
    # chat-template-file override.
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

  # First boot downloads the 14.7GB model file (see services.llama-cpp
  # above); the default systemd startup timeout would kill that partway
  # through.
  systemd.services.llama-cpp.serviceConfig.TimeoutStartSec = "30min";

  programs = {
    # Registers zsh as a valid login shell; users.users.igor.shell above is
    # what makes it igor's actual default.
    zsh.enable = true;
    # Needs the 32-bit graphics support enabled above.
    steam.enable = true;
    # Shorter, friendlier front-end for nixos-rebuild (build-tree progress, a
    # diff of the generation change); flake points it at the installed
    # checkout so `nh os switch` needs no other arguments.
    nh = {
      enable = true;
      flake = "/etc/nixos";
    };
  };

  environment.systemPackages = [
    pkgs.git
    pkgs.nano
  ];

  # JetBrainsMono Nerd Font: patched with the icon glyphs Starship's prompt
  # expects (see home.nix). Select it as Konsole's profile font; Plasma's own
  # interface keeps the Noto fonts the plasma6 module installs.
  fonts.packages = [ pkgs.nerd-fonts.jetbrains-mono ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Compatibility version, not the Nixpkgs update channel. Do not change it
  # after installation without reading the NixOS release notes.
  system.stateVersion = "26.05";
}
