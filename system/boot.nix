{ pkgs, ... }:

{
  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Use 6.6 LTS kernel to avoid AMD GPU bug in kernel 6.12.10+
  # See: https://bbs.archlinux.org/viewtopic.php?id=303556
  boot.kernelPackages = pkgs.linuxPackages_6_6;

  # Load AMD GPU driver early in boot (fixes display detection before SDDM starts)
  boot.initrd.kernelModules = [ "amdgpu" ];

  # AMD GPU kernel parameters for suspend/resume stability
  # amdgpu.runpm=0: Disable runtime PM (prevents GPU power state issues on RX 6600 XT)
  # amdgpu.gpu_recovery=1: Enable GPU recovery on errors
  # amdgpu.dc_mst_support=0: Disable DisplayPort MST (not needed for single monitor, fixes ACT timeout errors after resume)
  boot.kernelParams = [
    "amdgpu.runpm=0"
    "amdgpu.gpu_recovery=1"
    "amdgpu.dc_mst_support=0"
  ];

  # Root impermanence: Rollback root subvolume to pristine state on boot.
  # Runs as a systemd initrd service (required for NixOS 26.05+ where systemd initrd is default).
  # Must run after device discovery (initrd-root-device.target) and before root is mounted (sysroot.mount).
  boot.initrd.systemd.enable = true;
  boot.initrd.systemd.services.rollback = {
    description = "Roll back root subvolume to blank snapshot";
    wantedBy = [ "initrd.target" ];
    after = [ "initrd-root-device.target" ];
    before = [ "sysroot.mount" ];
    unitConfig.DefaultDependencies = "no";
    serviceConfig.Type = "oneshot";
    script = ''
      set -e
      mkdir -p /mnt
      mount -t btrfs -o subvolid=5 /dev/disk/by-label/nixos /mnt

      # Delete nested subvolumes using bash built-ins (grep/cut unavailable in systemd initrd)
      while subvols=$(btrfs subvolume list -o /mnt/@) && [ -n "$subvols" ]; do
        while IFS= read -r line; do
          subvol=''${line##* }
          echo "deleting /$subvol subvolume..."
          btrfs subvolume delete "/mnt/$subvol" || true
        done <<< "$subvols"
      done

      echo "deleting /@ subvolume..."
      btrfs subvolume delete /mnt/@
      echo "restoring blank /@ subvolume..."
      btrfs subvolume snapshot /mnt/@blank /mnt/@
      umount /mnt
    '';
  };
}
