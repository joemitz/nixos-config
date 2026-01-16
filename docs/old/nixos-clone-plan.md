# Disk Clone Plan: sda → nvme0n1

## Overview
Clone the current NixOS system from 512GB sda to 1TB nvme0n1 using Clonezilla, then expand the filesystem to use the full disk capacity.

## Current Configuration

**Source Disk (sda - 512GB):**
- sda1: 1GB FAT32 (label: BOOT, ESP)
- sda2: 475.9GB Btrfs (label: nixos)
  - Contains 155 Btrfs subvolumes including:
    - Primary: @, @nix, @blank, @persist-root, @persist-dotfiles, @persist-userfiles
    - Snapper snapshots: Multiple snapshots under each persist subvolume
  - Current usage: 85.42GiB / 475.94GiB

**Target Disk (nvme0n1 - 1TB):**
- Will be completely overwritten during clone
- Final size after resize: ~1TB usable

**System Configuration:**
- Uses device labels (not UUIDs) for mounting - this is ideal for cloning
- Boot: systemd-boot with EFI
- Kernel: 6.6 LTS with early amdgpu loading
- Impermanence: Root (@) wiped on every boot, restored from @blank
- Three persistence subvolumes with neededForBoot=true

## Phase 1: Pre-Clone Preparation

### 1.1 Verify System State
Before cloning, ensure the system is in a clean state:

```bash
# Check disk usage and verify labels
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT,UUID

# Verify all persistence subvolumes are mounted
mount | grep persist

# Check Btrfs filesystem health
sudo btrfs filesystem show /dev/disk/by-label/nixos
sudo btrfs scrub start -B /dev/sda2
sudo btrfs scrub status /dev/sda2

# Verify no filesystem errors
sudo btrfs check --readonly /dev/sda2

# Check that recent Borg backup completed successfully
sudo systemctl status persist-backup.service
journalctl -u persist-backup.service -n 50
```

### 1.2 Sync and Flush
Ensure all data is written to disk:

```bash
# Sync all cached writes
sync

# Optional: Run one final backup before cloning
sudo systemctl start persist-backup.service
```

## Phase 2: Clonezilla Clone Operation

### 2.1 Boot Clonezilla Live USB
1. Create Clonezilla Live USB if not already done
2. Boot from Clonezilla USB (ensure both sda and nvme0n1 are connected)
3. Select language and keymap

### 2.2 Clonezilla Settings

**Mode Selection:**
- Choose: **device-device** (disk to disk clone)
- Choose: **Beginner mode** (recommended) or **Expert mode** (for more control)

**Recommended Clonezilla Options:**

**In Beginner Mode:**
1. Select source disk: **sda**
2. Select target disk: **nvme0n1**
3. When asked about checking filesystem: Choose **-fsck-src-part** (check source filesystem)
4. Accept default settings

**In Expert Mode (if you choose this):**
Select these options:
- `-g auto` - Automatically determine partition table type (will use GPT)
- `-e1 auto` - Automatically adjust filesystem geometry for the destination
- `-e2` - Use sfdisk for partition table creation (default, reliable)
- `-r` - Resize partition table proportionally (skip this, we'll resize manually after)
- `-rescue` - Continue even if errors occur (only if you want to be aggressive)
- `-fsck-src-part` - Check and repair source filesystem before cloning
- `-k1` - Create partition table proportionally in target disk (skip this, we'll resize manually)

**Critical Option:** Choose **`-k0`** - Create the partition table as-is (do NOT proportionally resize yet)
- We'll resize manually after clone for better control

**Verification:**
- When asked to check the image: Choose **Yes, check the image before restoring**

### 2.3 Execute Clone
1. Confirm all settings
2. Type "y" twice to confirm
3. Clone will take 30-60 minutes depending on data (85GB used + 155 subvolumes)
4. **Do not interrupt** - let it complete fully
5. After completion, choose **reboot**

## Phase 3: Post-Clone Filesystem Expansion

After cloning, the target disk will have the same partition sizes as the source (475.9GB). We need to expand to use the full 1TB.

### 3.1 Boot from Live USB (NixOS or GParted Live)
Boot from a live USB (NOT from either sda or nvme0n1) to safely resize:

```bash
# List disks to verify the clone
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT

# Expected output:
# nvme0n1      931.5G
# ├─nvme0n1p1    1G   vfat   BOOT
# └─nvme0n1p2  475.9G btrfs  nixos  (needs expansion)
```

### 3.2 Expand Partition Table

```bash
# Install parted if not available
nix-shell -p parted

# Check current partition layout
sudo parted /dev/nvme0n1 print

# Resize partition 2 to use all remaining space
sudo parted /dev/nvme0n1 resizepart 2 100%

# Verify new partition size
sudo parted /dev/nvme0n1 print
# Should now show nvme0n1p2 as ~930GB
```

### 3.3 Expand Btrfs Filesystem

```bash
# The Btrfs filesystem still thinks it's 475.9GB
# Expand it to fill the new partition size
sudo btrfs filesystem resize max /dev/nvme0n1p2

# Verify the resize
sudo btrfs filesystem show /dev/disk/by-label/nixos
# Should now show ~930GB total size

# Run a scrub to verify filesystem integrity after resize
sudo btrfs scrub start -B /dev/nvme0n1p2
sudo btrfs scrub status /dev/nvme0n1p2
```

## Phase 4: First Boot from nvme0n1

### 4.1 Configure UEFI Boot Order
Before booting, ensure UEFI firmware is set to boot from nvme0n1:

1. Reboot and enter UEFI/BIOS setup (usually Del or F2)
2. Go to Boot menu
3. Set nvme0n1 as first boot device (look for "Samsung SSD 990 PRO")
4. Disable or move sda to lower priority
5. Save and exit

**Alternative:** Remove sda physically before first boot to ensure you're testing nvme0n1

### 4.2 First Boot Verification

```bash
# After booting from nvme0n1, verify we're on the right disk
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT

# Should show nvme0n1p2 mounted at multiple points (root, /nix, persist mounts)

# Verify Btrfs filesystem size
sudo btrfs filesystem show /dev/disk/by-label/nixos
# Should show ~930GB total with ~85GB used

# Check all subvolumes are present
sudo btrfs subvolume list /
# Should show all 155 subvolumes

# Verify all persistence mounts
mount | grep persist
# Should show:
# - /persist-root on /persist-root
# - /persist-dotfiles on /persist-dotfiles
# - /persist-userfiles on /persist-userfiles

# Check system boots correctly with impermanence
# The @ subvolume should be freshly recreated from @blank
ls -la /

# Verify SSH host keys persisted
ls -la /persist-root/etc/ssh/

# Verify machine-id persisted
cat /persist-root/etc/machine-id

# Test network connectivity
ping -c 3 1.1.1.1

# Verify NFS mount works
ls /mnt/truenas/plex

# Check that services started correctly
systemctl status NetworkManager docker tailscaled sddm
```

### 4.3 Rebuild System (Optional but Recommended)

```bash
# Rebuild to ensure systemd-boot is correctly installed on nvme0n1's ESP
cd /home/joemitz/nixos-config
nhs

# This will:
# 1. Update systemd-boot on the ESP
# 2. Regenerate boot entries
# 3. Auto-commit changes
# 4. Verify everything activates correctly
```

### 4.4 Test Reboot

```bash
# Reboot to verify impermanence works correctly
sudo reboot

# After reboot, verify @ was wiped and recreated
# Check that all your persistent data is still there:
ls ~/nixos-config  # Should be in /persist-userfiles
ls ~/.config       # Should be in /persist-dotfiles
```

## Phase 5: Final Cleanup

### 5.1 Remove Source Disk (sda)
Once you've verified everything works correctly on nvme0n1:

1. Shut down the system: `sudo shutdown -h now`
2. Physically remove the sda disk from the system
3. Boot from nvme0n1 - should work normally

### 5.2 Final Verification

```bash
# After removing sda, verify only nvme0n1 is present
lsblk

# Should only show nvme0n1 (no sda)

# Run a final system check
sudo btrfs scrub start -B /dev/nvme0n1p2

# Verify Borg backups continue working
sudo systemctl start persist-backup.service
journalctl -u persist-backup.service -f
```

## Rollback Plan

If something goes wrong during or after the clone:

1. **Before removing sda:** Simply boot back to sda, it remains untouched
2. **If nvme0n1 won't boot:**
   - Boot from sda
   - Mount nvme0n1p2 to inspect issues
   - Can re-clone if necessary
3. **If data corruption:**
   - Boot from sda
   - Restore from latest Borg backup to nvme0n1
   - Repository: ssh://borg@192.168.0.100:2222/backup/nixos-persist

## Key Safety Points

✅ **Safe:**
- Source disk (sda) is never modified during clone
- Label-based mounting means no UUID conflicts
- Can boot from either disk during testing phase

⚠️ **Caution:**
- Both disks will have identical machine-id and SSH host keys if run simultaneously
- Ensure correct boot device in UEFI before booting
- Don't interrupt Clonezilla during clone operation

🔴 **Critical:**
- Keep sda until nvme0n1 is fully verified (at least 2-3 successful boots)
- Verify Borg backups are working before removing sda
- Test impermanence works (@ wipe/restore on boot)

## Estimated Timeline

- Pre-clone verification: 10 minutes
- Clonezilla clone: 30-60 minutes (85GB data + metadata for 155 subvolumes)
- Post-clone resize: 10 minutes
- First boot testing: 15 minutes
- **Total: ~1.5 - 2 hours**

## Files Requiring No Modification

Thanks to label-based mounting, no NixOS configuration files need to be modified:
- `system/hardware-configuration.nix` - Uses `/dev/disk/by-label/nixos` ✅
- `system/boot.nix` - No device-specific paths ✅
- All other config files - No changes needed ✅
