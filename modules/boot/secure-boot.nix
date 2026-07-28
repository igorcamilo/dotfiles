{ lib, pkgs, ... }:

{
  boot = {
    initrd.systemd.enable = true;
    loader = {
      efi.canTouchEfiVariables = true;

      systemd-boot.enable = lib.mkForce false; # Lanzaboote installs it itself.
    };
    lanzaboote = {
      enable = true;
      pkiBundle = "/var/lib/sbctl";

      # No keys exist during installation, so the first boot runs unsigned and
      # creates them. Enrolling them into firmware stays manual.
      autoGenerateKeys.enable = true;
      autoEnrollKeys.enable = false;

      configurationLimit = 8;
      measuredBoot = {
        enable = true;
        pcrs = [
          4
          7
        ];
      };
    };
  };

  environment.systemPackages = [ pkgs.sbctl ];
}
