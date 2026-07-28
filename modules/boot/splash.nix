_:

{
  boot = {
    plymouth = {
      enable = true;
      theme = "bgrt";
    };

    consoleLogLevel = 3;
    initrd.verbose = false;
    kernelParams = [
      "quiet"
      "rd.udev.log_level=3"
      "rd.systemd.show_status=auto"
    ];
  };

  # Loads amdgpu before Plymouth, so the splash starts at its final resolution.
  hardware.amdgpu.initrd.enable = true;
}
