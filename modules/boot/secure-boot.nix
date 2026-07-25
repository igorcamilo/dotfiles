{ lib, pkgs, ... }:

{
  boot = {
    initrd.systemd.enable = true;
    loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot.enable = lib.mkForce false;
    };
    lanzaboote = {
      enable = true;
      pkiBundle = "/var/lib/sbctl";
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
