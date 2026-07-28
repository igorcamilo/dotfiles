{ lib, pkgs, ... }:

{
  boot = {
    initrd.systemd.enable = true;
    loader = {
      efi.canTouchEfiVariables = true;

      # Lanzaboote installs systemd-boot itself.
      systemd-boot.enable = lib.mkForce false;
    };
    lanzaboote = {
      enable = true;
      pkiBundle = "/var/lib/sbctl";

      # Keys do not exist during installation, so the first boot runs
      # unsigned and creates them. Firmware enrollment stays manual.
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
