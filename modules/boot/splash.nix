_:

{
  boot = {
    plymouth = {
      enable = true;
      theme = "bgrt";
    };

    # Keep routine boot messages behind the splash. Press Escape during boot
    # to switch between Plymouth and the text details.
    consoleLogLevel = 3;
    initrd.verbose = false;
    kernelParams = [
      "quiet"
      "rd.udev.log_level=3"
      "rd.systemd.show_status=auto"
    ];
  };

  # Loads the amdgpu driver during the initrd, before Plymouth starts, so the
  # splash renders at its final resolution instead of flickering when the
  # driver takes over later in boot.
  hardware.amdgpu.initrd.enable = true;
}
