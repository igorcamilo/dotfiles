{
  imports = [
    ./disko.nix
    ./hardware-configuration.nix
    ../../modules/virtualisation/utm.nix
  ];

  networking.hostName = "igor-vm";
}
