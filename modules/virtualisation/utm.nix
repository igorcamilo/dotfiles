_:

{
  boot = {
    # Load the virtual GPU early so Plymouth can draw before LUKS is unlocked.
    initrd.kernelModules = [ "virtio_gpu" ];

    # QEMU's ARM machine prefers its serial console. Also show early boot and
    # the LUKS prompt on UTM's graphical display.
    kernelParams = [ "console=tty0" ];
  };

  hardware.graphics.enable = true;
  services.qemuGuest.enable = true;
  services.spice-vdagentd.enable = true;
}
