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

  home.username = "igor";
  home.homeDirectory = "/home/igor";
  home.stateVersion = "26.05";

  # Secret Service integration: lets applications, including
  # NetworkManager, store and retrieve secrets through KeePassXC instead
  # of gnome-keyring or KWallet. See README.md.
  programs.keepassxc = {
    enable = true;
    autostart = true;
    settings = {
      FdoSecrets.Enabled = true;
    };
  };

  # Hyprland session and Quickshell shells (bar + lock screen). The
  # greeter has its own copy of Quickshell's config, published via
  # environment.etc in configuration.nix instead of home-manager, since
  # it runs as a separate system user with no home directory here.
  home.file.".config/hypr/hyprland.conf".source = ./dotfiles/hypr/hyprland.conf;
  home.file.".config/quickshell/shell.qml".source = ./dotfiles/quickshell/bar/shell.qml;
  home.file.".config/quickshell/lockscreen".source = ./dotfiles/quickshell/lockscreen;
  home.file.".config/quickshell/shared".source = ./dotfiles/quickshell/shared;

  programs.ghostty.enable = true;

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
