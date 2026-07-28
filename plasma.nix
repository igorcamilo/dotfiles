_:

# After changing anything in System Settings, capture it as Nix and add it
# here instead of leaving it untracked:
#
#   nix run github:nix-community/plasma-manager#rc2nix

{
  programs.plasma = {
    enable = true;
    workspace.lookAndFeel = "org.kde.breezedark.desktop";
  };

  programs.konsole = {
    enable = true;
    defaultProfile = "igor";
    profiles.igor.font = {
      # The Nerd Font that configuration.nix installs, so Starship's prompt
      # glyphs render.
      name = "JetBrainsMono Nerd Font";
      size = 11;
    };
  };
}
