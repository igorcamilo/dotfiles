_:

# Hand-written Plasma settings, for what config-sync cannot capture: rc2nix
# blocks LookAndFeelPackage, ColorScheme and Theme as uninteresting state, so
# the global theme has to be declared rather than snapshotted.

{
  programs.plasma = {
    enable = true;
    workspace.lookAndFeel = "org.kde.breezedark.desktop";
  };

  programs.konsole = {
    enable = true;
    defaultProfile = "igor";
    profiles.igor.font = {
      name = "JetBrainsMono Nerd Font"; # Starship's prompt glyphs need it.
      size = 11;
    };
  };
}
