{ config, pkgs, ... }:

{
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
}
