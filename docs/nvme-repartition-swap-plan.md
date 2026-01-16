# NixOS NVMe Repartitioning Plan: Add Swap Partition for AMD GPU Suspend/Resume Fix

## Problem
KWin crashes on wake from sleep due to AMD GPU driver bug. The amdgpu driver requires sufficient RAM to evacuate 8GB of VRAM during suspend, but with no swap configured, the system runs out of memory and crashes.

## Solution
1. Add 16GB swap partition on NVMe drive (/dev/nvme0n1)
2. Configure kernel parameters (already done in boot.nix)
3. Configure swap in hardware-configuration.nix

## Critical Files
- `/home/joemitz/nixos-config/system/hardware-configuration.nix` - Add swap configuration
- `/home/joemitz/nixos-config/system/boot.nix` - Kernel params already configured

## Current Disk Layout
```
/dev/nvme0n1 (931.5GB total)
├─ nvme0n1p1: 1GB    - EFI boot partition (FAT32, label: BOOT)
└─ nvme0n1p2: 930GB  - Btrfs partition (label: nixos)
   └─ Subvolumes: @, @nix, @blank, @persist-root, @persist-dotfiles, @persist-userfiles

Usage: 120GB used, 800GB free (13% utilization)
```

## Achieved Disk Layout
```
/dev/nvme0n1 (931.5GB total)
├─ nvme0n1p1: 1GB / 1 GiB      - EFI boot partition (unchanged)
├─ nvme0n1p2: 983GB / 915.4GiB - Btrfs partition (shrunk by 15GB)
└─ nvme0n1p3: 16.2GB / 15.1GiB - Swap partition (new, label: "swap")
```

---

## CURRENT STATUS

**✅ Phase 1 Complete** (Pre-repartitioning Safety)
- ✅ Step 1.1: Critical data backed up to TrueNAS
- ✅ Step 1.2: Btrfs filesystem verified healthy (930GB total, 115GB used, 804GB free)
- ✅ Step 1.3: Configuration documented (files saved to `/home/joemitz/nixos-config/docs/`)

**✅ Phase 2 Complete** (Repartitioning from OpenSUSE System)
- ✅ Step 2.1: NVMe drive identified (/dev/nvme0n1)
- ✅ Step 2.2: Btrfs filesystem mounted
- ✅ Step 2.3: Btrfs filesystem shrunk from 930.5GB to 910.5GB
- ✅ Step 2.4: Filesystem unmounted
- ✅ Step 2.5: Partition 2 resized to 983GB (915.4 GiB)
- ✅ Step 2.6: Swap partition created: 16.2GB (15.1 GiB) with label "swap"
- ✅ Step 2.7: Btrfs expanded to fill partition (915.4 GiB)
- ✅ Step 2.8: Final verification - Btrfs scrub completed with 0 errors
- ✅ Step 2.9: Filesystem unmounted and synced

**→ NEXT: Phase 3** - Boot NixOS and configure swap in hardware-configuration.nix

Final partition layout achieved:
- Partition 1: 1GB - EFI boot (unchanged)
- Partition 2: 915.4 GiB (983 GB) - Btrfs nixos
- Partition 3: 15.1 GiB (16.2 GB) - Swap (UUID: 00193ae4-ffe3-4b69-a8c0-ba384c207391)

Configuration backups available at:
- `/home/joemitz/nixos-config/docs/partition-table-backup.txt`
- `/home/joemitz/nixos-config/docs/btrfs-subvolumes-backup.txt`
- `/home/joemitz/nixos-config/docs/blkid-backup.txt`

---

## PHASE 1: PRE-REPARTITIONING SAFETY (From NixOS System)

### Step 1.1: Backup Critical Data
**MANDATORY** - Do this before any disk operations!

```bash
# Ensure TrueNAS mount is available
ls -la /mnt/truenas/kopia/

# Create backup directory with timestamp
BACKUP_DIR="/mnt/truenas/kopia/backup-$(date +%Y%m%d-%H%M%S)"
sudo mkdir -p "$BACKUP_DIR"

# Backup all persistent data (this is EVERYTHING that survives reboots)
sudo rsync -av --progress /persist-userfiles/ "$BACKUP_DIR/persist-userfiles/"
sudo rsync -av --progress /persist-dotfiles/ "$BACKUP_DIR/persist-dotfiles/"
sudo rsync -av --progress /persist-root/ "$BACKUP_DIR/persist-root/"

# Verify backups
du -sh "$BACKUP_DIR"/*
```

**Alternative**: If TrueNAS unavailable, backup to external USB drive or sda3

### Step 1.2: Verify Btrfs Filesystem Health
Check for corruption before resize operations:

```bash
# Check overall Btrfs health (mounted, read-only check)
sudo btrfs filesystem show /dev/nvme0n1p2
sudo btrfs filesystem usage /

# Check for errors in dmesg
sudo dmesg | grep -i btrfs | grep -i error

# Optional: Run scrub to verify checksums (takes 10-30 min)
# Only if you have time - not strictly required for healthy filesystem
sudo btrfs scrub start -B /
sudo btrfs scrub status /
```

**Expected**: No errors. If errors found, DO NOT PROCEED - fix filesystem first.

### Step 1.3: Document Current Configuration
Save partition table and filesystem info for recovery if needed:

```bash
# Save partition table backup
sudo fdisk -l /dev/nvme0n1 > ~/nixos-config/docs/partition-table-backup.txt

# Save Btrfs subvolume list
sudo btrfs subvolume list / > ~/nixos-config/docs/btrfs-subvolumes-backup.txt

# Save filesystem UUIDs
sudo blkid > ~/nixos-config/docs/blkid-backup.txt
```

**Note**: Files are saved to the docs folder and will be committed with the config.
If you also backed up to TrueNAS, that's even better!

### Step 1.4: Shutdown NixOS
Once backups verified, shut down the NixOS system:

```bash
sudo shutdown -h now
```

---

## PHASE 2: REPARTITIONING (From Another Linux System)

### Prerequisites on Second Linux System
Install required tools:
```bash
# Debian/Ubuntu
sudo apt install parted btrfs-progs util-linux

# Arch/Manjaro
sudo pacman -S parted btrfs-progs util-linux

# Fedora
sudo dnf install parted btrfs-progs util-linux
```

### Step 2.1: Mount NVMe and Verify Device
Connect NixOS drive and identify it:

```bash
# List all disks - find the NixOS NVMe (usually 931.5GB)
lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINT

# Verify it's the correct disk - should show:
# - 1GB partition labeled "BOOT" (vfat)
# - ~930GB partition labeled "nixos" (btrfs)
sudo blkid | grep nixos

# Set device variable (ADJUST if different!)
DISK="/dev/nvme0n1"  # or /dev/sda, /dev/sdb, etc - CHECK CAREFULLY!
BTRFS_PART="${DISK}p2"

# SAFETY: Verify this is correct before proceeding
echo "Target disk: $DISK"
echo "Btrfs partition: $BTRFS_PART"
sudo parted "$DISK" print
# READ THE OUTPUT - Confirm it's the right disk!
```

**CRITICAL**: Triple-check you have the correct disk! Wrong disk = data loss!

### Step 2.2: Create Mount Point and Mount Btrfs
```bash
sudo mkdir -p /mnt/nixos-btrfs
sudo mount "$BTRFS_PART" /mnt/nixos-btrfs

# Verify mount successful
df -h /mnt/nixos-btrfs
sudo btrfs filesystem show /mnt/nixos-btrfs
sudo btrfs filesystem usage /mnt/nixos-btrfs
```

**Expected**: Should show ~800GB free space, multiple subvolumes

### Step 2.3: Shrink Btrfs Filesystem (Step 1 of 3)
**Important**: We shrink in stages with safety margin to avoid rounding errors.

```bash
# Current size: ~930GB
# Target partition: ~914.5GB
# Safety margin: Shrink filesystem to 910GB (extra 4.5GB buffer)

# Shrink Btrfs filesystem by 20GB (provides 4.5GB safety margin)
sudo btrfs filesystem resize -20G /mnt/nixos-btrfs

# Verify shrink successful
sudo btrfs filesystem show /mnt/nixos-btrfs
sudo btrfs filesystem usage /mnt/nixos-btrfs

# Check for errors
sudo dmesg | tail -50 | grep -i btrfs
```

**Expected**: Filesystem now shows ~910GB total size, no errors

**If errors occur**: STOP - unmount, run `btrfs check`, resolve issues

### Step 2.4: Unmount Filesystem
Must unmount before partition resize:

```bash
sudo umount /mnt/nixos-btrfs

# Verify unmounted
mount | grep nixos-btrfs  # Should be empty
```

### Step 2.5: Resize Partition (Step 2 of 3)
Shrink the partition to target size:

```bash
# Check current partition alignment
sudo parted "$DISK" align-check optimal 2

# Start parted in interactive mode
sudo parted -a optimal "$DISK"

# Inside parted:
(parted) print
# Note the current size of partition 2 (should be ~930GB)

(parted) resizepart 2
End? [930GB]? 914GB
# This shrinks partition 2 from ~930GB to 914GB

(parted) print
# Verify partition 2 is now 914GB

(parted) quit
```

**Alternative non-interactive method**:
```bash
sudo parted -a optimal "$DISK" ---pretend-input-tty <<EOF
resizepart 2
914GB
quit
EOF
```

### Step 2.6: Create Swap Partition (Step 3 of 3)
Create new partition in freed space:

```bash
# Create partition 3 for swap using all remaining space
sudo parted -a optimal "$DISK" mkpart primary linux-swap 914GB 100%

# Verify partition created
sudo parted "$DISK" print

# Check alignment (should say "aligned")
sudo parted "$DISK" align-check optimal 3

# Create swap filesystem with label
sudo mkswap -L swap "${DISK}p3"

# Verify swap created
sudo blkid | grep swap
```

**Expected**: New nvme0n1p3 partition (~16GB) with label "swap"

### Step 2.7: Expand Btrfs to Fill Partition
Remount Btrfs and expand to use full partition:

```bash
# Remount Btrfs partition
sudo mount "$BTRFS_PART" /mnt/nixos-btrfs

# Expand Btrfs filesystem to maximum size (fills partition)
sudo btrfs filesystem resize max /mnt/nixos-btrfs

# Verify expansion
sudo btrfs filesystem show /mnt/nixos-btrfs
sudo btrfs filesystem usage /mnt/nixos-btrfs
```

**Expected**: Filesystem should now be ~914GB (matches partition size)

### Step 2.8: Final Verification
Verify all partitions are correct:

```bash
# Show final partition layout
sudo parted "$DISK" print
lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL "$DISK"
sudo blkid | grep nvme0n1

# Verify Btrfs health
sudo btrfs scrub start -B /mnt/nixos-btrfs
sudo btrfs scrub status /mnt/nixos-btrfs

# Check dmesg for errors
sudo dmesg | grep -i btrfs | grep -i error
sudo dmesg | grep -i nvme | grep -i error
```

**Expected Output**:
- Partition 1: 1GB, vfat, label "BOOT"
- Partition 2: 914GB, btrfs, label "nixos"
- Partition 3: 16GB, swap, label "swap"
- Btrfs scrub: 0 errors
- No error messages in dmesg

### Step 2.9: Unmount and Power Off
```bash
sudo umount /mnt/nixos-btrfs
sudo sync

# Power off the second system
sudo shutdown -h now

# Disconnect NixOS drive and reinstall in NixOS system
```

---

## PHASE 3: CONFIGURE NIXOS (Boot NixOS System)

**🔹 YOU ARE HERE - BOOT NIXOS AND CONFIGURE SWAP 🔹**

### Step 3.1: Boot NixOS and Verify Partitions
After reinstalling NVMe in NixOS system, power on and log in:

```bash
# Verify all partitions present
lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINT
sudo blkid

# Check swap partition specifically
sudo blkid -L swap

# Verify Btrfs mounted correctly
df -h /
sudo btrfs filesystem show /
```

**Expected**: All three partitions visible, root filesystem mounted correctly

### Step 3.2: Test Swap Activation (Manual)
Before configuring NixOS, test swap works:

```bash
# Activate swap manually
sudo swapon /dev/disk/by-label/swap

# Verify swap active
free -h
swapon --show
cat /proc/swaps
```

**Expected**: Should show 16GB swap active

```bash
# Disable for now (NixOS will manage it)
sudo swapoff /dev/disk/by-label/swap
```

### Step 3.3: Update hardware-configuration.nix
Edit the hardware configuration file:

```bash
cd ~/nixos-config
micro system/hardware-configuration.nix
```

**Change line 55** from:
```nix
  swapDevices = [ ];
```

To:
```nix
  swapDevices = [
    { device = "/dev/disk/by-label/swap"; }
  ];
```

**Note**: Using `by-label` is reliable and readable. Alternative: use `by-partuuid` from `blkid`.

### Step 3.4: Verify boot.nix Configuration
Kernel parameters already configured. Verify they're present:

```bash
cat system/boot.nix | grep -A 3 "boot.kernelParams"
```

**Expected output**:
```nix
boot.kernelParams = [
  "amdgpu.runpm=0"
  "amdgpu.gpu_recovery=1"
];
```

### Step 3.5: Rebuild NixOS
Apply configuration:

```bash
# DO NOT use nhs (it auto-commits) until we verify it works
sudo nh os switch ~/nixos-config
```

**Expected**: Build succeeds, system switches to new generation

### Step 3.6: Verify Swap Active After Rebuild
```bash
# Check swap is active
free -h
swapon --show
cat /proc/swaps

# Verify kernel parameters
cat /proc/cmdline | grep amdgpu
```

**Expected**:
- Swap: 16GB total
- Kernel params: `amdgpu.runpm=0 amdgpu.gpu_recovery=1`

---

## PHASE 4: TESTING & VERIFICATION

### Step 4.1: Test Suspend/Resume
Test the fix works:

```bash
# Suspend system
systemctl suspend

# Wait 10 seconds, wake system (press power button or key)

# After wake, check for KWin crash
journalctl -b 0 --no-pager | grep -i kwin | grep -i "Failed to open drm"

# Check GPU state
lspci -k | grep -A 3 VGA
dmesg | tail -50 | grep amdgpu
```

**Expected**:
- No "Failed to open drm device" errors
- No KWin crash
- System wakes cleanly

### Step 4.2: Multiple Suspend/Resume Cycles
Test stability:

```bash
# Test 3-5 suspend/resume cycles
for i in {1..5}; do
  echo "Test cycle $i"
  systemctl suspend
  sleep 5
  # Wake system manually
  sleep 30  # Wait after wake
  journalctl -b 0 --no-pager | tail -20 | grep -i error
done
```

### Step 4.3: Check Swap Usage
After several suspend cycles:

```bash
# Check if swap was used
free -h
sudo dmesg | grep -i swap

# Check for GPU-related memory operations
sudo dmesg | grep -i amdgpu | grep -i suspend
```

### Step 4.4: Monitor System Logs
Check for any issues:

```bash
# Check for errors
journalctl -b 0 --priority=err
journalctl -b 0 --priority=warning | grep -i amdgpu

# Check Btrfs health
sudo btrfs filesystem show /
sudo btrfs device stats /
```

**Expected**: No critical errors, Btrfs healthy

---

## PHASE 5: COMMIT CONFIGURATION (After Successful Testing)

### Step 5.1: Commit Changes
Once testing confirms the fix works:

```bash
cd ~/nixos-config

# Use nhs to auto-commit (will invoke Claude to generate message)
nhs
```

**Expected commit message**: Something like "add 16gb swap partition and amdgpu kernel parameters for suspend/resume stability"

---

## ROLLBACK PROCEDURES

### If Repartitioning Fails (During Phase 2)

**Symptom**: Btrfs won't shrink, partition operation fails, etc.

**Recovery**:
1. Do NOT proceed further
2. If Btrfs filesystem was shrunk but partition resize failed:
   ```bash
   sudo mount "$BTRFS_PART" /mnt/nixos-btrfs
   sudo btrfs filesystem resize max /mnt/nixos-btrfs
   sudo umount /mnt/nixos-btrfs
   ```
3. Restore from backup if needed
4. Boot NixOS normally - system should work unchanged

### If NixOS Won't Boot (After Phase 3)

**Symptom**: System doesn't boot, drops to emergency shell

**Recovery**:
1. Boot NixOS from USB live environment
2. Mount root:
   ```bash
   sudo mount -o subvol=@ /dev/disk/by-label/nixos /mnt
   sudo mount /dev/disk/by-label/BOOT /mnt/boot
   ```
3. Chroot and rebuild previous generation:
   ```bash
   sudo nixos-enter --root /mnt
   nixos-rebuild switch --rollback
   exit
   reboot
   ```

### If Swap Doesn't Activate

**Symptom**: System boots but swap is 0 bytes

**Diagnosis**:
```bash
sudo swapon -v /dev/disk/by-label/swap
sudo journalctl -u systemd-swap.service
```

**Fix**: Verify label exists (`blkid`), check hardware-configuration.nix syntax

---

## DISK SPACE CALCULATIONS

- **Before**: 930.5 GiB Btrfs (115 GiB used, 804 GiB free)
- **After**: 915.4 GiB Btrfs (115 GiB used, 789 GiB free), 15.1 GiB swap
- **Lost space**: 15 GiB (allocated to swap)
- **Safety margin**: 5 GiB was temporarily used during resize, now reclaimed
- **Actual partition sizes (GB vs GiB)**: 983 GB = 915.4 GiB (Btrfs), 16.2 GB = 15.1 GiB (swap)

---

## SOURCES & REFERENCES

**Btrfs Resizing**:
- [Red Hat: Resizing a btrfs File System](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/7/html/storage_administration_guide/resizing-btrfs)
- [Manjaro: HowTo Resize a btrfs filesystem](https://forum.manjaro.org/t/howto-resize-a-btrfs-filesystem/152999)
- [Arch Wiki: Parted](https://wiki.archlinux.org/title/Parted)

**Btrfs Health Checks**:
- [BTRFS Documentation: btrfs-check](https://btrfs.readthedocs.io/en/latest/btrfs-check.html)
- [BTRFS Documentation: Scrub](https://btrfs.readthedocs.io/en/latest/Scrub.html)

**NixOS Swap Configuration**:
- [NixOS Wiki: Swap](https://nixos.wiki/wiki/Swap)
- [NixOS Discourse: How to add a swap after NixOS installation](https://discourse.nixos.org/t/how-to-add-a-swap-after-nixos-installation/41742)

**Partition Alignment**:
- [Arch Wiki: Parted - Alignment](https://wiki.archlinux.org/title/Parted#Alignment)
- [GNU Parted Manual](https://www.gnu.org/software/parted/manual/parted.html)

**AMD GPU Suspend Issues**:
- [nyanpasu64: How I helped fix sleep-wake hangs on Linux with AMD GPUs](https://nyanpasu64.gitlab.io/blog/amdgpu-sleep-wake-hang/)
- [Arch Forums: AmdGPU crashed after resume from suspend](https://bbs.archlinux.org/viewtopic.php?id=285925)

---

## ESTIMATED TIME

- Phase 1 (Backup): 15-30 minutes
- Phase 2 (Repartitioning): 30-45 minutes
- Phase 3 (NixOS Config): 10-15 minutes
- Phase 4 (Testing): 20-30 minutes
- **Total**: 1.5 to 2 hours

## RISK ASSESSMENT

- **Data loss risk**: LOW (with proper backups)
- **Bootability risk**: VERY LOW (rollback available)
- **Filesystem corruption risk**: VERY LOW (850GB free space, no data movement)
- **Overall risk**: LOW (well-tested procedure, plenty of safety margins)

**Critical success factors**:
1. Verify backups before starting
2. Triple-check disk device names
3. Follow shrink order: filesystem → partition → expand
4. Test swap activation before committing configuration
