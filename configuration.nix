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

    # Pairing UI and polkit rules for the Bluetooth radio enabled above.
    blueman.enable = true;

    fwupd.enable = true;

    desktopManager.plasma6.enable = true;
    displayManager.sddm.enable = true;

    udisks2.enable = true;

    btrfs.autoScrub.enable = true;

    # ROCm 7.2 (2026-03) added official support for this GPU (RDNA4/gfx1201);
    # rocmOverrideGfx (sets HSA_OVERRIDE_GFX_VERSION) is the fallback if a
    # future package update ever fails to detect it, not needed by default.
    # loadModels pulls a coding model straight from its GGUF source on first
    # activation - see docs/ideas.md for the full model/hardware feasibility
    # notes. Q3_K_M is the quantization that actually fits this card's 16GB
    # alongside the desktop's own VRAM usage (Q4_K_M alone is 18.6GB, already
    # over budget before the desktop takes anything).
    #
    # Runs Qwen3-Coder-30B-A3B (a mixture-of-experts model: 30B total
    # parameters, ~3B active per token - see docs/ideas.md for the full
    # model/hardware feasibility notes) through llama.cpp's own llama-server
    # instead of Ollama. Reason for the switch: Ollama's offload logic isn't
    # MoE-aware (open upstream issues about misplacing expert layers on
    # partial offload), while llama-server's n-cpu-moe setting can
    # deliberately park the coldest expert weights in system RAM and pull
    # back only the ones a given token actually routes to - that's what buys
    # headroom for a real context window on top of a model this size, which
    # plain VRAM-fit alone can't. Q3_K_M (14.7GB) is still the quantization
    # that fits this card's 16GB alongside Hyprland's own usage (Q4_K_M alone
    # is 18.6GB). hf-repo pulls the same GGUF straight from its source on
    # first start, same as Ollama's old loadModels, caching it under
    # /var/cache/llama-cpp (this module sets LLAMA_CACHE there) so later
    # restarts don't re-download it.
    #
    # n-gpu-layers/n-cpu-moe/ctx-size below are a first-pass starting point,
    # not tuned numbers: llama-server logs its actual VRAM allocation at
    # startup, and both offload settings need adjusting from there until it
    # fits next to Hyprland's own VRAM draw. flash-attn = "auto" lets it fall
    # back safely if ROCm/gfx1201 flash-attention support is flaky on the
    # exact ROCm point release in use, rather than hard-failing.
    #
    # VS Code integration is manual: run "Chat: Manage Language Models" ->
    # Add Models -> Custom Endpoint -> Chat Completions, URL
    # http://127.0.0.1:8080/v1/chat/completions, model id
    # "qwen3-coder-30b-a3b" (the alias below). Set "toolCalling": true on
    # that model in the chatLanguageModels.json VS Code opens for you -
    # without it Copilot only offers this model in Ask mode, not Agent mode.
    # Known caveat: the chat template embedded in this GGUF 500s on tool
    # calls whose parameters have no "properties" field - see
    # https://huggingface.co/unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF/discussions/10
    # for the community patch (a chat-template-file override) if that trips
    # you up before upstream fixes it.
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

  # Desktop: Plasma 6, the NixOS-documented default KDE install
  # (services.desktopManager.plasma6 + services.displayManager.sddm). It
  # brings its own Qt/GTK theming (Breeze + kde-gtk-config), portals
  # (xdg-desktop-portal-kde + kwallet), and polkit agent
  # (polkit-kde-agent-1), so none of those need declaring by hand here.
  programs = {
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

  environment.systemPackages = [
    pkgs.git
    # The installed checkout contains LFS-tracked wallpapers.
    pkgs.git-lfs
    pkgs.nano
  ];

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
