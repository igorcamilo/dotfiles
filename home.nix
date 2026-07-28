{ pkgs, ... }:

{
  home = {
    username = "igor";
    homeDirectory = "/home/igor";
    stateVersion = "26.05";

    # Konsole, Dolphin, Kate, Spectacle and the rest of the standard Plasma
    # applications come from services.desktopManager.plasma6 in
    # configuration.nix, so only genuinely extra ones belong here. ffmpeg is
    # the system H.264/AAC decoder Firefox loads at run time; it cannot bundle
    # those codecs itself.
    packages = [
      pkgs.ffmpeg
      pkgs.godot

      # Cycles only renders on the GPU when Blender is built with HIP.
      # nixpkgs dropped the blender-hip attribute in favour of ROCm-enabled
      # package sets; this override is the same thing scoped to one package
      # instead of rebuilding a second nixpkgs. It is a local source build -
      # the binary cache only carries the CPU-only Blender, and
      # WITH_CYCLES_HIP_BINARIES compiles Cycles kernels for every supported
      # AMD architecture, gfx1201 (RX 9070 XT) included - so expect the first
      # build to be long. Pick the device afterwards under Settings > System >
      # Cycles Render Devices > HIP; Blender does not select it by itself.
      (pkgs.blender.override { rocmSupport = true; })
    ];

    sessionVariables = {
      # VS Code is Electron; without this it falls back to XWayland instead of
      # running natively under KWin's Wayland session.
      NIXOS_OZONE_WL = "1";
    };
  };

  programs = {
    # Firefox is GTK, so it picks up the Breeze GTK theme that plasma6's
    # kde-gtk-config keeps in sync with the Plasma color scheme.
    firefox = {
      enable = true;
      profiles.igor = {
        isDefault = true;
        # Mesa's radeonsi VA-API driver comes from hardware.graphics.enable in
        # configuration.nix; this just tells Firefox to actually use it
        # instead of decoding video on the CPU.
        settings."media.ffmpeg.vaapi.enabled" = true;
      };
    };

    # Declarative so settings.json and argv.json stay owned by this repo
    # instead of VS Code's own Settings Sync fighting the same files.
    vscode = {
      enable = true;
      # No local-LLM extension here: Copilot Chat's own "Custom Endpoint"
      # model picker entry talks to llama.cpp's llama-server directly (see
      # services.llama-cpp in configuration.nix for the connection details).
      profiles.default.userSettings = {
        "diffEditor.experimental.showMoves" = true;
        "diffEditor.renderSideBySide" = false;
        "git.confirmSync" = false;
        "git.inputValidation" = true;
        "github.copilot.chat.commitMessageGeneration.instructions" = [
          {
            "text" = "Limit header to 50 characters max and body lines to 72 characters max.";
          }
        ];
        # KWin draws a native title bar for VS Code's window, so the
        # min/max/close controls in VS Code's own custom title bar are dead
        # weight (needs a full restart of VS Code to take effect).
        "window.controlsStyle" = "hidden";
      };
      # VS Code writes both of these into argv.json on first run. Declaring
      # them means it has no missing field to write back into what is now a
      # read-only Nix-store symlink. crash-reporter-id is an
      # install-correlation id, not a secret, but VS Code's own comment asks
      # not to change it once assigned. Chromium's password-store is left
      # undeclared so it auto-detects KWallet, which Plasma provides.
      argvSettings = {
        "enable-crash-reporter" = true;
        "crash-reporter-id" = "6eeb860a-4e8d-482b-bae9-b6fd7c3f17dd";
      };
    };

    # home-manager-managed (not just enabled in configuration.nix) so that
    # Starship's shell hook below gets woven into ~/.zshrc automatically.
    zsh.enable = true;
    starship = {
      enable = true;
      settings = {
        add_newline = false;
        format = "$username$hostname$directory$git_branch$character";
      };
    };
  };
}
