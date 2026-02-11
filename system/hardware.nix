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

  # Mount OpenSUSE home subvolume (read-only)
  fileSystems."/mnt/opensuse" = {
    device = "/dev/disk/by-uuid/8590c09a-138e-4615-b02d-c982580e3bf8";
    fsType = "btrfs";
    options = [ "ro" "subvol=@/home" "compress=zstd" "noatime" ];
  };
}
