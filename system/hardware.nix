_:

{
  # AMD GPU hardware acceleration
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Explicitly set AMD GPU as video driver
  services.xserver.videoDrivers = [ "amdgpu" ];

  # Enable Bluetooth (built-in and USB dongles)
  hardware.bluetooth.enable = true;

  # Enable firmware updates
  services.fwupd.enable = true;

  # Mount TrueNAS Plex share via NFS (read-only)
  fileSystems."/mnt/truenas/plex" = {
    device = "192.168.0.55:/mnt/main-pool/plex";
    fsType = "nfs";
    options = [ "ro" ];
  };
}
