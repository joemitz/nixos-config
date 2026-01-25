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
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  # Enable firmware updates
  services.fwupd.enable = true;

  # Mount TrueNAS Kopia share via NFS (read-write)
  # x-systemd.automount: Mount on first access (not at boot)
  # _netdev: Network filesystem (systemd waits for network automatically)
  # nofail: Continue boot even if mount fails
  fileSystems."/mnt/truenas/kopia" = {
    device = "192.168.0.55:/mnt/main-pool/kopia";
    fsType = "nfs";
    options = [
      "rw"
      "x-systemd.automount"
      "_netdev"
      "nofail"
      "x-systemd.mount-timeout=30s"
    ];
  };

  # Mount OpenSUSE home subvolume (read-only)
  fileSystems."/mnt/opensuse" = {
    device = "/dev/disk/by-uuid/8590c09a-138e-4615-b02d-c982580e3bf8";
    fsType = "btrfs";
    options = [ "ro" "subvol=@/home" "compress=zstd" "noatime" ];
  };
}
