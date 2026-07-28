_:

# Hand-written Plasma settings. rc2nix deliberately drops a few keys as
# uninteresting state, so anything it blocks has to be declared here or it
# stays untracked: LookAndFeelPackage, ColorScheme and Theme are the ones that
# matter, which is why the whole global theme lives in this file.
#
# Everything else is captured into plasma-generated.nix by config-sync.

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
