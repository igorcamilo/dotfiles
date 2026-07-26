_:

{
  boot = {
    # Load the virtual GPU early so Plymouth can draw before LUKS is unlocked.
    initrd.kernelModules = [ "virtio_gpu" ];

    # QEMU's ARM machine prefers its serial console. Also show early boot and
    # the LUKS prompt on UTM's graphical display. Plymouth must ignore the
    # still-active serial console or it may put its UI on ttyAMA0 instead.
    kernelParams = [
      "console=tty0"
      "plymouth.ignore-serial-consoles"
    ];
  };

  hardware.graphics.enable = true;
  services.qemuGuest.enable = true;
  services.spice-vdagentd.enable = true;
}
