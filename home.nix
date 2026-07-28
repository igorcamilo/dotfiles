{ pkgs, ... }:

{
  home = {
    username = "igor";
    homeDirectory = "/home/igor";
    stateVersion = "26.05";

    packages = [
      pkgs.bitwarden-desktop
      pkgs.ffmpeg # H.264/AAC decoding for Firefox, which cannot bundle it.
      pkgs.godot

      # Cycles needs HIP to render on the GPU, and nixpkgs has no prebuilt
      # ROCm Blender, so this builds from source and takes hours. Select the
      # device under Settings > System > Cycles Render Devices > HIP.
      (pkgs.blender.override { rocmSupport = true; })
    ];

    # Without this, VS Code and other Electron apps fall back to XWayland.
    sessionVariables.NIXOS_OZONE_WL = "1";
  };

  programs = {
    firefox = {
      enable = true;

      # Plasma Integration is useless without its native messaging host, and
      # the copy plasma6 installs system-wide is invisible to this wrapped
      # Firefox - the wrapper only links in what it is given here.
      nativeMessagingHosts = [ pkgs.kdePackages.plasma-browser-integration ];

      # Keys are add-on ids on addons.mozilla.org. force_installed means this
      # file owns the extension: to remove one, remove it here.
      policies.ExtensionSettings = {
        "{446900e4-71c2-419f-a6a7-df9c091e268b}" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/bitwarden-password-manager/latest.xpi";
          installation_mode = "force_installed";
        };
        # Media controls in the panel and on the lock screen, downloads in
        # notifications, and open tabs in KRunner.
        "plasma-browser-integration@kde.org" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/plasma-integration/latest.xpi";
          installation_mode = "force_installed";
        };
      };

      profiles.igor = {
        isDefault = true;
        settings."media.ffmpeg.vaapi.enabled" = true; # Decode video on the GPU.
      };
    };

    vscode = {
      enable = true;
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
        # KWin draws the title bar, so VS Code's own window controls are dead
        # weight. Needs a full restart of VS Code.
        "window.controlsStyle" = "hidden";
      };
      # VS Code writes these on first run; declaring them stops it from trying
      # to write into a read-only store symlink.
      argvSettings = {
        "enable-crash-reporter" = true;
        "crash-reporter-id" = "6eeb860a-4e8d-482b-bae9-b6fd7c3f17dd";
      };
    };

    # Managed here, not only in configuration.nix, so Starship's hook lands in
    # ~/.zshrc.
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
