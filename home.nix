{ pkgs, ... }:

{
  # Starting an already-active oneshot service is idempotent, which closes the
  # race that a pgrep-based lock guard would leave between concurrent callers.
  systemd.user.services.quickshell-lock = {
    Unit.Description = "Quickshell Wayland session lock";
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.quickshell}/bin/quickshell -c lockscreen";
    };
  };

  systemd.user.services.quickshell-launcher = {
    Unit.Description = "Quickshell app launcher";
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.quickshell}/bin/quickshell -c launcher";
    };
  };

  home = {
    username = "igor";
    homeDirectory = "/home/igor";
    stateVersion = "26.05";

    # hyprpolkitagent: GUI polkit agent, started from hyprland.conf. dolphin:
    # file manager bound in hyprland.conf. playerctl and wireplumber (wpctl):
    # back the media-key binds in hyprland.conf.
    packages = [
      pkgs.hyprpolkitagent
      pkgs.kdePackages.dolphin
      pkgs.playerctl
      pkgs.wireplumber
    ];

    # Hyprland session and Quickshell shells (bar, lock screen, launcher).
    # The greeter has its own copy of Quickshell's config, published via
    # environment.etc in configuration.nix instead of home-manager, since
    # it runs as a separate system user with no home directory here.
    file = {
      ".config/hypr/hyprland.conf".source = ./dotfiles/hypr/hyprland.conf;
      ".config/quickshell/shell.qml".source = ./dotfiles/quickshell/bar/shell.qml;
      ".config/quickshell/lockscreen".source = ./dotfiles/quickshell/lockscreen;
      ".config/quickshell/launcher".source = ./dotfiles/quickshell/launcher;
      ".config/quickshell/shared".source = ./dotfiles/quickshell/shared;
    };
  };

  programs = {
    # Secret Service integration: lets applications, including
    # NetworkManager, store and retrieve secrets through KeePassXC instead
    # of gnome-keyring or KWallet. See README.md.
    keepassxc = {
      enable = true;
      autostart = true;
      settings = {
        FdoSecrets.Enabled = true;
      };
    };

    ghostty = {
      enable = true;
      settings = {
        theme = "catppuccin-mocha";
        font-family = "JetBrainsMono Nerd Font";
        window-padding-x = 10;
        window-padding-y = 10;
        window-decoration = false;
      };
    };

    # Firefox is GTK3, so it already picks up the adw-gtk3-dark theme and
    # Papirus icons below for its native chrome (dialogs, scrollbars). Its
    # own tab/toolbar chrome is a separate layer, themed via userChrome on
    # the profile below once there's a real stylesheet to put there.
    firefox = {
      enable = true;
      profiles.igor.isDefault = true;
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

  # GTK4/libadwaita apps ignore a full theme override (see the gtk.gtk4.theme
  # warning in home-manager's own module), so only GTK3 gets one: adw-gtk3
  # mimics libadwaita's look, keeping GTK3 and GTK4 apps consistent without
  # fighting GTK4 for it. colorScheme and iconTheme apply to both versions.
  gtk = {
    enable = true;
    theme = {
      name = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    colorScheme = "dark";
  };

  xdg.autostart.enable = true;

  # Auto-lock on idle: lock at 5 minutes, blank the display 30 seconds
  # after that, lock again before suspend regardless of idle time.
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "systemctl --user start quickshell-lock.service";
        before_sleep_cmd = "systemctl --user start quickshell-lock.service";
        after_sleep_cmd = "hyprctl dispatch dpms on";
      };
      listener = [
        {
          timeout = 300;
          on-timeout = "systemctl --user start quickshell-lock.service";
        }
        {
          timeout = 330;
          on-timeout = "hyprctl dispatch dpms off";
          on-resume = "hyprctl dispatch dpms on";
        }
      ];
    };
  };
}
