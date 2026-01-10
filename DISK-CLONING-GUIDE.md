# NixOS Disk Cloning Guide

## System Information

**Motherboard:** ASUS PRIME A320I-K Rev X.0x
**BIOS:** American Megatrends Inc. version 1820 (09/12/2019)
**Current Disk:** /dev/sda (Samsung SSD)
**Boot Partition:** /dev/sda1 (LABEL=BOOT, PARTUUID=9066f58f-19fa-455c-a6a8-60fa0ec03237)
**Root Partition:** /dev/sda2 (LABEL=nixos)

## Why This Works

Your NixOS configuration uses **filesystem labels** instead of UUIDs in hardware-configuration.nix:
- `device = "/dev/disk/by-label/nixos";`
- `device = "/dev/disk/by-label/BOOT";`

This means filesystems will be found correctly after cloning because labels are cloned with the disk.

The only issue is the **EFI boot variable** which references the old disk's PARTUUID. This guide shows you how to handle that.

## Pre-Cloning Checklist

- [ ] Verify current system boots correctly
- [ ] Run `nhs` to ensure latest configuration is committed
- [ ] Have new target disk ready (same size or larger)
- [ ] Create Clonezilla bootable USB
- [ ] **Do NOT delete any boot entries before cloning** (keeps current system bootable)

## Cloning Process

### Step 1: Clone with Clonezilla

1. Boot from Clonezilla USB
2. Select "device-device" mode (disk to disk clone)
3. Select source disk (current system disk)
4. Select target disk (new disk)
5. Complete the clone process
6. Shut down (do not reboot yet)

### Step 2: Prepare Hardware

**IMPORTANT:** Disconnect the old disk before first boot to avoid:
- Duplicate filesystem label conflicts
- Confusion about which disk to boot from

## Post-Clone Boot Process

### Method 1: Boot Override (Easiest)

1. Power on and **immediately press F8** (Boot Menu key)
2. You should see a list of bootable devices
3. Select your new disk from the list
4. System should boot normally

**If it boots successfully:**
- Open terminal
- Run: `sudo nh os switch /home/joemitz/nixos-config`
- This updates EFI variables with the new disk's PARTUUID
- Reboot to verify automatic boot works
- **Done!**

### Method 2: Manual Boot Option (If F8 doesn't show disk)

1. Power on and **press F2 or Del** to enter BIOS
2. Press **F7** to enter Advanced Mode
3. Navigate to **Boot** tab
4. Look for **Add Boot Option** or similar
5. Create new boot entry:
   - Name: "NixOS Manual"
   - File system: Select your new disk's EFI partition
   - Path: `\EFI\BOOT\BOOTX64.EFI`
6. Save (F10) and reboot
7. System should boot

**Once booted:**
- Run: `sudo nh os switch /home/joemitz/nixos-config`
- This creates proper boot entries
- **Done!**

### Method 3: EFI Shell (Advanced)

1. Power on and press **F2 or Del** to enter BIOS
2. Press **F7** to enter Advanced Mode
3. Navigate to **Exit** tab
4. Select **Launch EFI Shell from filesystem device**
5. In the shell, type:
   ```
   fs0:
   cd \EFI\BOOT
   BOOTX64.EFI
   ```
   (Try fs0:, fs1:, fs2:, etc. until you find the right partition)

**Once booted:**
- Run: `sudo nh os switch /home/joemitz/nixos-config`
- **Done!**

## Verification Steps

After running `nh os switch`, verify the fix:

```bash
# Check new boot entries were created
nix-shell -p efibootmgr --run "efibootmgr -v"

# You should see entries with your new disk's PARTUUID

# Check system status
sudo systemctl status
```

Reboot to confirm automatic boot works without manual intervention.

## If Something Goes Wrong

### Can't Boot New Disk At All

**Option A: Reconnect old disk temporarily**
1. Shut down
2. Reconnect old disk (alongside new disk)
3. Boot from old disk using F8 boot menu
4. Investigate issue or try cloning again

**Option B: Boot from NixOS installation media**
1. Boot from NixOS installation USB
2. Mount the new disk:
   ```bash
   sudo mount -o subvol=@ /dev/disk/by-label/nixos /mnt
   sudo mount -o subvol=@nix /dev/disk/by-label/nixos /mnt/nix
   sudo mount /dev/disk/by-label/BOOT /mnt/boot
   ```
3. Enter the system:
   ```bash
   sudo nixos-enter
   ```
4. Fix boot entries:
   ```bash
   nixos-rebuild switch
   ```
5. Exit and reboot

### Duplicate Label Issues (If both disks connected)

If you need both disks connected:
1. Relabel the new disk:
   ```bash
   # For Btrfs filesystem
   sudo btrfs filesystem label /dev/sdX nixos-new

   # For boot partition
   sudo fatlabel /dev/sdX1 BOOT-NEW
   ```
2. Update hardware-configuration.nix with new labels
3. Run `sudo nh os switch`

## Expected Results

- **First boot:** May require manual intervention (F8 boot menu)
- **After running nh os switch:** Automatic boot should work
- **No data loss:** All files and configuration preserved
- **All features working:** Impermanence, Btrfs, backups, everything intact

## Why No Installation Media Needed

Your ASUS motherboard has multiple manual boot selection methods:
- F8 Boot Override menu
- Add Boot Option feature in BIOS
- Launch EFI Shell option

The bootloader file (`\EFI\BOOT\BOOTX64.EFI`) exists on the cloned disk, you just need to tell the firmware where to find it once.

## References

- [ASUS Boot Menu Access - Official Support](https://www.asus.com/support/faq/1013017/)
- [ASUS Boot Device Priorities - Official Support](https://www.asus.com/support/faq/1053205/)
- [UEFI Boot Options - ASUS ROG Forum](https://rog-forum.asus.com/t5/promotions-general-discussions/uefi-bios-boot-options/td-p/763352)
- [systemd-boot - ArchWiki](https://wiki.archlinux.org/title/Systemd-boot)
- [UEFI Boot Process Explained](https://www.happyassassin.net/posts/2014/01/25/uefi-boot-how-does-that-actually-work-then/)

## Additional Notes

- Keep the old disk as backup until you verify new disk is fully working
- Consider running Snapper snapshots before cloning
- Borg backups continue to work after cloning (same SSH key persisted)
- No need to update secrets - sops age key is persisted in /persist-dotfiles
