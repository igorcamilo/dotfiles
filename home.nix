_:

{
  imports = [
    ./plasma.nix
    ./plasma-generated.nix
  ];

  home = {
    username = "igor";
    homeDirectory = "/home/igor";
    stateVersion = "26.05";
  };

  # Every package here is already installed system-wide in configuration.nix,
  # so package = null keeps Home Manager from installing a second copy into the
  # user profile; the module then only writes configuration.
  programs = {
    firefox = {
      enable = true;
      package = null;
      profiles.igor = {
        isDefault = true;
        settings."media.ffmpeg.vaapi.enabled" = true; # Decode video on the GPU.
      };
    };

    vscode = {
      enable = true;
      package = null;
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

    zsh = {
      enable = true;
      # Capture the live Plasma settings, update every flake input, and
      # rebuild. rc2nix writes to stdout, and via a temporary file so a failed
      # dump cannot truncate plasma-generated.nix. /etc/nixos is the symlink
      # to the checkout, so this works wherever the repository was cloned.
      shellAliases.config-sync = builtins.concatStringsSep " && " [
        "rc2nix > /tmp/plasma-generated.nix"
        "mv /tmp/plasma-generated.nix /etc/nixos/plasma-generated.nix"
        "nh os switch --update"
      ];
    };

    # No package = null: this module has no such option, so Starship's binary
    # comes from the user profile rather than environment.systemPackages.
    starship = {
      enable = true;
      settings = {
        add_newline = false;
        format = "$username$hostname$directory$git_branch$character";
      };
    };
  };
}
