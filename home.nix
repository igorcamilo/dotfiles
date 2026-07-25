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

  # Dotfiles can be declared here and tracked in this repository, e.g.:
  # home.file.".config/hypr/hyprland.conf".source = ./dotfiles/hyprland.conf;
}
