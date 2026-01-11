# Plan: Clone 931.5 GiB Disk to 500GB (465 GiB) Disk

## Objective
Clone the current openSUSE system from a 1TB Samsung 990 PRO to a 500GB disk, resizing all partitions to fit while maintaining bootability and data integrity.

## Current State Analysis

**Source Disk:** /dev/nvme0n1 (931.51 GiB)
- p1: 66.7M BIOS boot
- p2: 914.8G btrfs (UUID: 8590c09a-138e-4615-b02d-c982580e3bf8)
  - Allocated: 483.07 GiB
  - Used: 372.44 GiB (actual data)
  - 32 subvolumes including 8 snapshots (3140-3147)
  - Currently booted from snapshot 3142
  - Metadata: DUP (duplicated), 8.34 GiB
- p3: 16.7G swap

**Target Disk:** 500GB (~465 GiB total)
- p1: 66.7M (same)
- p2: ~448 GiB (shrunk from 914.8G) - **This is the challenge**
- p3: 16.7G (same)

**Key Challenge:** Btrfs has 483.07 GiB allocated but target partition is only 448 GiB. Must consolidate allocated space through balancing before shrinking.

## Research Summary

Based on web research:
- [Btrfs Resize Documentation](https://btrfs.readthedocs.io/en/latest/Resize.html) - Shrinking requires data relocation and is IO intensive
- [Manjaro Btrfs Guide](https://forum.manjaro.org/t/howto-resize-a-btrfs-filesystem/152999) - Recommends 20% safety margin when shrinking
- [Clonezilla Guide](https://www.aomeitech.com/clone-tips/clonezilla-larger-disk-to-smaller-disk-0044.html) - Requires Expert mode with -icds option for smaller disk cloning
- [NVIDIA Balance Guide](https://docs.nvidia.com/networking-ethernet-software/knowledge-base/Configuration-and-Usage/Storage/When-to-Rebalance-BTRFS-Partitions/) - Balance needed when allocated space is significantly higher than used

## Implementation Strategy

### Operations Breakdown

**From Running System:**
- Phase 0: Preparation and health checks
- Phase 1: Btrfs balance (can also be done from live USB if preferred)
- Initial cleanup and verification

**From Live USB (Required):**
- Phase 3: Filesystem shrink (filesystem must be unmounted)
- Phase 4: Partition resize (partition table modification)
- Phase 5: Clone to target disk
- Phase 6: Post-clone configuration (UUID updates, GRUB reinstall)

## Detailed Implementation Plan

---

### Phase 0: Preparation (Running System)

**Duration:** 1 hour | **Risk:** Low

#### 0.1: Create Backup Directory and Capture State

```bash
mkdir -p ~/disk-clone-prep

# Capture current configuration
sudo fdisk -l /dev/nvme0n1 > ~/disk-clone-prep/fdisk-before.txt
sudo parted /dev/nvme0n1 unit s print > ~/disk-clone-prep/parted-before.txt
sudo btrfs filesystem show > ~/disk-clone-prep/btrfs-fs-before.txt
sudo btrfs filesystem usage / > ~/disk-clone-prep/btrfs-usage-before.txt
sudo btrfs subvolume list / > ~/disk-clone-prep/subvolumes-before.txt
sudo blkid > ~/disk-clone-prep/blkid-before.txt
cat /etc/fstab > ~/disk-clone-prep/fstab-backup.txt
```

#### 0.2: Filesystem Health Check

```bash
# Check for filesystem errors (will take time)
sudo btrfs scrub start /
watch -n 60 'sudo btrfs scrub status /'

# Wait for completion, verify 0 errors
sudo btrfs scrub status /
```

**Verification:** Scrub must complete with 0 errors before proceeding.

#### 0.3: Optional Cleanup

```bash
# Delete oldest snapshots (keeping 3142-3147)
sudo snapper delete 3140 3141

# Clean package cache
sudo zypper clean -a

# Clear old journal logs
sudo journalctl --vacuum-time=3d

# Check updated usage
sudo btrfs filesystem usage /
```

---

### Phase 1: Btrfs Balance (Running System or Live USB)

**Duration:** 3-6 hours | **Risk:** Medium | **IO:** Very Heavy

**Goal:** Reduce allocated space from 483 GiB to below 420 GiB (leaves 28 GiB safety margin for 448 GiB target)

#### 1.1: Pre-Balance Check

```bash
sudo btrfs filesystem usage / | tee ~/disk-clone-prep/usage-pre-balance.txt
```

Note the "Data, single: Size" value - should be ~461 GiB allocated.

#### 1.2: Balance Data Chunks

```bash
# This will take HOURS - be patient
sudo btrfs balance start -dusage=75 /

# Monitor in another terminal
watch -n 30 'sudo btrfs balance status /'
```

**Expected:** Data allocated drops to ~380-400 GiB

If balance is taking too long or system is unusable:
```bash
sudo btrfs balance pause /
# Resume later: sudo btrfs balance resume /
```

#### 1.3: Balance Metadata

```bash
sudo btrfs balance start -musage=75 /
```

#### 1.4: Verify Results

```bash
sudo btrfs filesystem usage / | tee ~/disk-clone-prep/usage-post-balance.txt

# Check total allocated (Data + Metadata + System)
# MUST be below 420 GiB to proceed
```

**CRITICAL CHECK:** If allocated space is still > 420 GiB, run more aggressive balance:
```bash
sudo btrfs balance start -dusage=85 /
# Or even: sudo btrfs balance start -dusage=95 /
```

**STOP HERE:** Do not proceed to Phase 3 until allocated space < 420 GiB.

---

### Phase 2: Boot to Live USB Environment

**Duration:** 10 minutes

#### 2.1: Boot to Live USB

1. Reboot with USB inserted
2. Boot to live environment
3. **Do not mount the filesystem automatically**

#### 2.2: Verify Tools Available

```bash
# Check disk is visible but unmounted
lsblk | grep nvme0n1p2
# Should show no mount point

# Verify tools are available
which btrfs parted gdisk
```

---

### Phase 3: Filesystem Shrink (Live USB - REQUIRED)

**Duration:** 1-3 hours | **Risk:** HIGH | **Point of No Return**

#### 3.1: Verify State Before Shrinking

```bash
# Mount read-only to check
sudo mkdir -p /mnt/check
sudo mount -o ro /dev/nvme0n1p2 /mnt/check
sudo btrfs filesystem usage /mnt/check

# CRITICAL: Verify allocated < 420 GiB
sudo umount /mnt/check
```

**STOP HERE IF:** Allocated space > 420 GiB - return to Phase 1

#### 3.2: Filesystem Integrity Check

```bash
# REQUIRED before shrinking
sudo btrfs check --readonly /dev/nvme0n1p2
```

**If errors found:** DO NOT PROCEED - investigate and repair first

#### 3.3: Shrink Filesystem

```bash
# Target: 425 GiB (conservative with 23 GiB margin)
sudo mkdir -p /mnt/shrink
sudo mount /dev/nvme0n1p2 /mnt/shrink

# THE POINT OF NO RETURN
sudo btrfs filesystem resize 425G /mnt/shrink
```

**Expected Duration:** 1-2 hours

**If "No space left on device" error:** Allocated space is still too high, must balance more.

#### 3.4: Verify Shrink Success

```bash
sudo btrfs filesystem show /mnt/shrink
# Should show 425 GiB

sudo btrfs filesystem usage /mnt/shrink
# All data should fit within 425 GiB

sudo umount /mnt/shrink

# Final check
sudo btrfs check --readonly /dev/nvme0n1p2
```

---

### Phase 4: Partition Resize (Live USB - REQUIRED)

**Duration:** 15-30 minutes | **Risk:** CRITICAL

#### 4.1: Backup Partition Table

```bash
sudo sgdisk --backup=/tmp/nvme0n1-gpt-backup.bin /dev/nvme0n1
sudo sgdisk --print /dev/nvme0n1 > /tmp/partition-table-before.txt
```

#### 4.2: Calculate New Partition Layout

```bash
# p2 new end sector calculation:
# 425 GiB = 456,261,632 KiB = 912,523,264 sectors (512 bytes)
# Add buffer: use end sector 912,800,000 (~447 GiB partition)

START_SECTOR=138570
END_SECTOR=912800000
```

#### 4.3: Resize Partition 2

```bash
# Delete and recreate p2 with new size
sudo parted /dev/nvme0n1 rm 2
sudo parted /dev/nvme0n1 mkpart primary btrfs 138570s 912800000s

# Verify
sudo parted /dev/nvme0n1 unit GiB print
```

**Expected:** p2 should now show ~447 GiB

#### 4.4: Move Swap Partition

```bash
# Calculate new position for p3 (swap)
NEW_P3_START=912800001

# Delete and recreate p3
sudo parted /dev/nvme0n1 rm 3
sudo parted /dev/nvme0n1 mkpart primary linux-swap ${NEW_P3_START}s 947800000s

# Recreate swap
sudo mkswap /dev/nvme0n1p3 -L "swap"
```

#### 4.5: Verify Filesystem Still Works

```bash
sudo mkdir -p /mnt/verify
sudo mount /dev/nvme0n1p2 /mnt/verify

# Verify all critical data accessible
ls -la /mnt/verify/@/.snapshots/3142/snapshot/
sudo btrfs subvolume list /mnt/verify

sudo umount /mnt/verify
```

**CRITICAL:** Filesystem must mount and be accessible

---

### Phase 5: Clone to Target Disk (Live USB)

**Duration:** 2-4 hours | **Risk:** Medium

#### 5.1: Identify Target Disk

```bash
# Connect 500GB disk
lsblk

# Verify target disk size
sudo fdisk -l /dev/sda  # Adjust device name as needed
```

**VERIFY CAREFULLY:** Ensure you've identified the correct target disk

#### 5.2: Method A - Using Clonezilla (Recommended)

Boot Clonezilla Live USB:
1. Select device-device clone
2. Select disk_to_local_disk
3. Source: nvme0n1, Target: sda (or appropriate device)
4. **Expert mode:** Enable `-icds` (ignore disk size checking)
5. Enable `-k1` (create partition table proportionally)
6. Start cloning

**Duration:** 2-4 hours depending on actual data

#### 5.3: Method B - Manual Clone

```bash
TARGET_DISK="/dev/sda"  # Verify this carefully!

# Create partition table on target
sudo parted /dev/$TARGET_DISK mklabel gpt

# Create partitions sized for 500GB disk
sudo parted /dev/$TARGET_DISK mkpart primary 2048s 138569s
sudo parted /dev/$TARGET_DISK set 1 bios_grub on

sudo parted /dev/$TARGET_DISK mkpart primary btrfs 138570s 941773168s

sudo parted /dev/$TARGET_DISK mkpart primary linux-swap 941773169s -1s
sudo parted /dev/$TARGET_DISK set 3 swap on

# Clone p1 (BIOS boot)
sudo dd if=/dev/nvme0n1p1 of=/dev/${TARGET_DISK}1 bs=4M status=progress

# Clone p2 (btrfs) - using partclone for efficiency
sudo partclone.btrfs -c -s /dev/nvme0n1p2 -o /dev/${TARGET_DISK}2

# Create swap
sudo mkswap /dev/${TARGET_DISK}3 -L "swap"
```

#### 5.4: Expand Filesystem on Target

```bash
# Mount target partition
sudo mkdir -p /mnt/target
sudo mount /dev/${TARGET_DISK}2 /mnt/target

# Expand filesystem to use full partition
sudo btrfs filesystem resize max /mnt/target

# Verify
sudo btrfs filesystem show /mnt/target
# Should show ~447 GiB

sudo umount /mnt/target
```

---

### Phase 6: Post-Clone Configuration (Live USB)

**Duration:** 30 minutes | **Risk:** Medium

#### 6.1: Update UUIDs in fstab

```bash
TARGET_DISK="/dev/sda"  # Adjust as needed

# Get new UUIDs
NEW_ROOT_UUID=$(sudo blkid -s UUID -o value /dev/${TARGET_DISK}2)
NEW_SWAP_UUID=$(sudo blkid -s UUID -o value /dev/${TARGET_DISK}3)

# Mount target root
sudo mount /dev/${TARGET_DISK}2 /mnt/target -o subvol=/@/.snapshots/3142/snapshot

# Update fstab
sudo sed -i "s/UUID=8590c09a-138e-4615-b02d-c982580e3bf8/UUID=$NEW_ROOT_UUID/" /mnt/target/etc/fstab
sudo sed -i "s/UUID=[a-f0-9-]* .*swap/UUID=$NEW_SWAP_UUID none swap/" /mnt/target/etc/fstab

# Verify changes
cat /mnt/target/etc/fstab
```

#### 6.2: Reinstall GRUB

```bash
# Mount necessary filesystems for chroot
sudo mount --bind /dev /mnt/target/dev
sudo mount --bind /proc /mnt/target/proc
sudo mount --bind /sys /mnt/target/sys
sudo mount --bind /run /mnt/target/run

# Chroot and reinstall GRUB
sudo chroot /mnt/target /bin/bash

# Inside chroot:
grub2-install /dev/$TARGET_DISK
grub2-mkconfig -o /boot/grub2/grub.cfg

# Regenerate initramfs
dracut --force --regenerate-all

exit
```

#### 6.3: Cleanup

```bash
sudo umount /mnt/target/dev /mnt/target/proc /mnt/target/sys /mnt/target/run
sudo umount /mnt/target
sync
```

---

### Phase 7: First Boot from New Disk

**Duration:** 10-20 minutes | **Risk:** Low

#### 7.1: Boot Preparation

1. Shutdown system
2. Remove old disk, install new disk (or select new disk in BIOS)
3. Boot from new disk

#### 7.2: Verify System

```bash
# Check correct disk is mounted
lsblk -f
df -h

# Verify btrfs status
sudo btrfs filesystem show /
sudo btrfs filesystem usage /

# Check swap
swapon --show
free -h

# Verify snapshots
sudo snapper list
cat /proc/cmdline
# Should show: subvol=/@/.snapshots/3142/snapshot
```

#### 7.3: System Health Check

```bash
# Check for boot errors
sudo journalctl -b -p err

# Start filesystem scrub
sudo btrfs scrub start /

# Monitor scrub progress
sudo btrfs scrub status /

# After completion, verify 0 errors
sudo btrfs device stats /
```

---

## Critical Files Modified

- **/etc/fstab** - Updated with new disk UUIDs
- **/boot/grub2/grub.cfg** - Regenerated to reference new UUIDs
- **/boot/grub2/device.map** - Updated by grub2-install
- Initramfs files in **/boot** - Regenerated with new UUID references

## Verification Checklist

**Before Phase 3 (Filesystem Shrink):**
- [ ] Scrub completed with 0 errors
- [ ] Allocated space < 420 GiB
- [ ] At least 28 GiB margin below target

**Before Phase 4 (Partition Resize):**
- [ ] Filesystem shrunk to 425 GiB
- [ ] Filesystem check shows no errors
- [ ] Partition table backed up

**Before Phase 7 (First Boot):**
- [ ] GRUB installed on target disk
- [ ] fstab updated with new UUIDs
- [ ] Initramfs regenerated
- [ ] All filesystems unmounted cleanly

**After First Boot:**
- [ ] System boots successfully
- [ ] All data accessible
- [ ] Snapper works
- [ ] Btrfs scrub shows 0 errors
- [ ] Free space ~75 GiB (447 - 372)

## Time Estimates

- **Total time:** 8-16 hours spread over 2-3 days
- **Most time-consuming:** Phase 1 (balance) 3-6 hours, Phase 5 (clone) 2-4 hours
- **System downtime:** ~4-7 hours (Phases 2-7 in live USB)

## Risk Assessment

**Highest Risk:** Phase 4 (partition table modification)
**Medium Risk:** Phase 3 (filesystem shrink), Phase 6 (bootloader config)
**Low Risk:** All other phases

**Critical:** Do not skip verification steps

---

## Quick Reference Summary

**Phase 0 - Preparation (Running System, ~1 hour)**
- Capture current disk state to ~/disk-clone-prep/
- Run btrfs scrub to check filesystem health (must show 0 errors)
- Optional: Delete old snapshots and clean package cache

**Phase 1 - Balance (Running System, 3-6 hours)**
- Run `btrfs balance start -dusage=75 /` to consolidate allocated space
- Goal: Reduce allocated from 483 GiB to below 420 GiB
- If still too high, run more aggressive balance with -dusage=85 or -dusage=95

**Phase 2 - Boot to Live USB (10 minutes)**
- Reboot with live USB inserted
- Boot to live environment
- Verify nvme0n1p2 is not mounted and tools are available

**Phase 3 - Shrink Filesystem (Live USB, 1-3 hours)**
- Check: allocated space must be < 420 GiB
- Run `btrfs check --readonly /dev/nvme0n1p2`
- Mount and run `btrfs filesystem resize 425G /mnt/shrink`
- Verify with btrfs check after unmounting

**Phase 4 - Resize Partitions (Live USB, 15-30 minutes)**
- Backup partition table with sgdisk
- Delete and recreate p2: start 138570s, end 912800000s (~447 GiB)
- Move swap partition p3 to start at 912800001s
- Recreate swap with mkswap
- Verify filesystem still mounts correctly

**Phase 5 - Clone to Target (Live USB, 2-4 hours)**
- Connect 500GB target disk, identify as /dev/sda (verify carefully!)
- Method A: Use Clonezilla with Expert mode, enable -icds flag
- Method B: Manual with parted + partclone.btrfs
- After clone, mount target and run `btrfs filesystem resize max` to expand to full partition

**Phase 6 - Configure Target (Live USB, 30 minutes)**
- Mount target disk and update /etc/fstab with new UUIDs
- Chroot into target system
- Run `grub2-install /dev/sda` and `grub2-mkconfig -o /boot/grub2/grub.cfg`
- Run `dracut --force --regenerate-all` to rebuild initramfs

**Phase 7 - First Boot (10-20 minutes)**
- Shutdown, install target disk (or boot from it via BIOS)
- Verify system boots to correct disk with `lsblk -f`
- Check btrfs status, swap, and snapshots
- Run `btrfs scrub start /` and verify 0 errors after completion
