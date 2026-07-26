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
}
