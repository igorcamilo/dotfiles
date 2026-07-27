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
      # The launcher calls Qt.quit() right after launching an app, so it can
      # close itself immediately; systemd's default KillMode=control-group
      # would then kill that just-launched app too, since it shares this
      # service's cgroup. KillMode=process only kills the tracked quickshell
      # process, letting whatever it launched keep running.
      KillMode = "process";
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

    # Without this, GTK/Qt apps fall back to whatever cursor their own
    # toolkit bundles, and Electron apps like VS Code fall back to
    # Chromium's built-in cursor - all visibly different from each other.
    # hyprcursor covers native Wayland clients; gtk covers GTK's own lookup
    # path; x11 covers XWayland clients (e.g. Steam).
    pointerCursor = {
      enable = true;
      package = pkgs.adwaita-icon-theme;
      name = "Adwaita";
      gtk.enable = true;
      hyprcursor.enable = true;
      x11.enable = true;
    };

    # Hyprland session and Quickshell shells (bar, lock screen, launcher).
    file = {
      ".config/hypr/hyprland.lua".source = ./dotfiles/hypr/hyprland.lua;
      # Quickshell treats a shell.qml at the quickshell/ root as *the* default
      # config and stops looking at named subfolders entirely, so the bar has
      # to be a named config (-c bar) like lockscreen/launcher, not the root.
      ".config/quickshell/bar".source = ./dotfiles/quickshell/bar;
      # Quickshell also confines each named config's imports to its own root,
      # and home-manager can't map a second file/directory nested inside a
      # path that's already one whole-directory symlink (fails at build time:
      # "Error installing file ... outside $HOME"), so lockscreen's shared/
      # components live physically inside dotfiles/quickshell/lockscreen/
      # rather than being deployed separately.
      ".config/quickshell/lockscreen".source = ./dotfiles/quickshell/lockscreen;
      ".config/quickshell/launcher".source = ./dotfiles/quickshell/launcher;
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
        # Ghostty's bundled themes are named after their upstream
        # iterm2-color-schemes file, which uses title case and a space.
        theme = "Catppuccin Mocha";
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

    # Declarative so settings.json and argv.json stay owned by this repo
    # instead of VS Code's own Settings Sync fighting the same files.
    vscode = {
      enable = true;
      profiles.default.userSettings = {
        # Hyprland handles window management, so the min/max/close controls
        # in VS Code's own custom title bar are dead weight (needs a full
        # restart of VS Code to take effect).
        "window.titleControlsStyle" = "hidden";
      };
      argvSettings = {
        # Under Hyprland (not a desktop environment Electron recognizes),
        # Chromium's keyring auto-detection falls back to an unencrypted
        # store, which is how the GitHub sign-in token ended up in plain
        # text. This forces the same Secret Service backend KeePassXC
        # already provides (also needs a full VS Code restart).
        "password-store" = "gnome-libsecret";
        # VS Code writes both of these into argv.json itself on first run.
        # Copied verbatim from igor-desktop's pre-Nix argv.json so VS Code
        # has no missing fields to try to write back into what is now a
        # read-only Nix-store symlink - crash-reporter-id in particular is
        # only an install-correlation id, not a secret, but VS Code's own
        # comment asks not to change it once assigned.
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

    # Hyprland draws no server-side title bar, so every CSD button (e.g.
    # Firefox's close/maximize/minimize, merged into its tab strip) is drawn
    # by GTK itself following this setting. Empty on both sides of the ":"
    # means no buttons on either side.
    gtk3.extraConfig."gtk-decoration-layout" = "";
    gtk4.extraConfig."gtk-decoration-layout" = "";
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
