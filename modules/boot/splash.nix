_:

{
  boot = {
    plymouth = {
      enable = true;
      theme = "bgrt";
    };

    # Press Escape during boot to switch between the splash and the messages.
    consoleLogLevel = 3;
    initrd.verbose = false;
    kernelParams = [
      "quiet"
      "rd.udev.log_level=3"
      "rd.systemd.show_status=auto"
    ];
  };

  # Loads amdgpu before Plymouth starts, so the splash renders at its final
  # resolution instead of flickering when the driver takes over.
  hardware.amdgpu.initrd.enable = true;
}
