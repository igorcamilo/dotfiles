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

  # package = null: these are installed system-wide, so the module writes
  # configuration without adding a second copy to the user profile.
  programs = {
    firefox = {
      enable = true;
      package = null;
      profiles.igor = {
        isDefault = true;
        settings."media.ffmpeg.vaapi.enabled" = true;
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
        "window.controlsStyle" = "hidden"; # KWin already draws a title bar.
      };
      # Declared because VS Code writes them itself on first run, and its
      # argv.json is a read-only store symlink.
      argvSettings = {
        "enable-crash-reporter" = true;
        "crash-reporter-id" = "6eeb860a-4e8d-482b-bae9-b6fd7c3f17dd";
      };
    };

    zsh = {
      enable = true;
      shellAliases = {
        # Through a temporary file: rc2nix only writes to stdout, and a failed
        # dump would otherwise truncate plasma-generated.nix.
        config-sync = builtins.concatStringsSep " && " [
          "rc2nix > /tmp/plasma-generated.nix"
          "mv /tmp/plasma-generated.nix /etc/nixos/plasma-generated.nix"
          "nh os switch --update"
        ];

        llama-start = "sudo systemctl start llama-cpp";
        llama-stop = "sudo systemctl stop llama-cpp"; # Frees the VRAM.
        llama-log = "journalctl --follow --unit llama-cpp";
      };
    };

    # Installs into the user profile: this module has no package option.
    starship = {
      enable = true;
      settings = {
        add_newline = false;
        format = "$username$hostname$directory$git_branch$character";
      };
    };
  };
}
