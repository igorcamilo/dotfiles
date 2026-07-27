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

    # hyprpolkitagent: GUI polkit agent, started from hyprland.lua. dolphin:
    # file manager bound in hyprland.lua, with ffmpegthumbs for its video
    # thumbnails. playerctl and wireplumber (wpctl): back the media-key binds
    # in hyprland.lua. ffmpeg: the system H.264/AAC decoder Firefox loads at
    # run time (it can't bundle those codecs itself; see the firefox profile
    # below). libva-utils: run `vainfo` to confirm GPU video decode is active.
    packages = [
      pkgs.hyprpolkitagent
      pkgs.kdePackages.dolphin
      pkgs.kdePackages.ffmpegthumbs
      # Kate and KWrite ship as one package upstream; kwrite below is the
      # lightweight one, kate the fuller editor, same binary set.
      pkgs.kdePackages.kate
      pkgs.playerctl
      pkgs.wireplumber
      pkgs.ffmpeg
      pkgs.libva-utils
      pkgs.vscode
    ];

    # nano is the plain terminal editor git commit/crontab -e/etc. expect
    # from $EDITOR; it blocks the caller by default, no extra flag needed.
    # NIXOS_OZONE_WL: VS Code (kept for manual use, not wired as a default)
    # is Electron; without this it falls back to XWayland instead of native
    # Wayland.
    sessionVariables = {
      EDITOR = "nano";
      VISUAL = "nano";
      NIXOS_OZONE_WL = "1";
    };

    # Hyprland session and Quickshell shells (bar, lock screen, launcher).
    file = {
      ".config/hypr/hyprland.lua".source = ./dotfiles/hypr/hyprland.lua;
      ".config/quickshell/shell.qml".source = ./dotfiles/quickshell/bar/shell.qml;
      # QML resolves same-directory types by filename with no import needed,
      # but only if the file is actually deployed alongside shell.qml.
      ".config/quickshell/Notifications.qml".source = ./dotfiles/quickshell/bar/Notifications.qml;
      ".config/quickshell/lockscreen".source = ./dotfiles/quickshell/lockscreen;
      ".config/quickshell/launcher".source = ./dotfiles/quickshell/launcher;
      ".config/quickshell/shared".source = ./dotfiles/quickshell/shared;
    };
  };

  programs = {
    # Stands in for gnome-keyring or KWallet as the Secret Service provider,
    # for applications that call that D-Bus API themselves. NetworkManager
    # does not: it reaches a Secret Service only through a NetworkManager
    # secret agent, which this session deliberately does not run, so Wi-Fi
    # passphrases stay in /etc/NetworkManager/system-connections on the
    # encrypted root rather than in a vault.
    #
    # Secret Service is left as a first-run GUI toggle instead of a declared
    # setting: home-manager links keepassxc.ini read-only into the store
    # whenever `settings` is non-empty, which would also stop KeePassXC from
    # recording which database to reopen on autostart.
    keepassxc = {
      enable = true;
      autostart = true;
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
      profiles.igor = {
        isDefault = true;
        # Mesa's radeonsi VA-API driver comes from hardware.graphics.enable
        # in configuration.nix; this just tells Firefox to actually use it
        # instead of decoding video on the CPU.
        settings."media.ffmpeg.vaapi.enabled" = true;
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

  xdg = {
    autostart.enable = true;

    # Equivalent to `xdg-mime default kwrite.desktop text/plain`, but
    # declarative in mimeapps.list, so it survives rebuilds. Named explicitly
    # (not via defaultApplicationPackages) since kate.desktop and
    # kwrite.desktop ship in the same package and both claim text/plain.
    mimeApps = {
      enable = true;
      defaultApplications."text/plain" = [ "kwrite.desktop" ];
    };
  };

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
