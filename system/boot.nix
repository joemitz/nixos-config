{ config, pkgs, ... }:

{
  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Use LTS kernel to avoid AMD GPU bug in kernel 6.12.10+
  # See: https://bbs.archlinux.org/viewtopic.php?id=303556
  boot.kernelPackages = pkgs.linuxPackages;

  # Load AMD GPU driver early in boot (fixes display detection before SDDM starts)
  boot.initrd.kernelModules = [ "amdgpu" ];

  # Root impermanence: Rollback root subvolume to pristine state on boot
  boot.initrd.postDeviceCommands = pkgs.lib.mkAfter ''
    mkdir -p /mnt

    # Mount the btrfs root to /mnt for subvolume manipulation
    mount -t btrfs -o subvolid=5 /dev/disk/by-uuid/a895216b-d275-480c-9b78-04c6a00df14a /mnt

    # === ROOT WIPE (use @blank) ===
    # Delete all nested subvolumes recursively before removing root
    while btrfs subvolume list -o /mnt/@ | grep -q .; do
      btrfs subvolume list -o /mnt/@ |
      cut -f9 -d' ' |
      while read subvolume; do
        echo "deleting /$subvolume subvolume..."
        btrfs subvolume delete "/mnt/$subvolume" || true
      done
    done

    echo "deleting /@ subvolume..."
    btrfs subvolume delete /mnt/@

    echo "restoring blank /@ subvolume..."
    btrfs subvolume snapshot /mnt/@blank /mnt/@

    # Unmount and continue boot process
    umount /mnt
  '';
}
