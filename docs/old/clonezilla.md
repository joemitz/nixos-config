# 🎯 HANDOFF: Phase 5 - Clonezilla Clone Instructions

## Current Status
The source disk (nvme0n1) is **ready to clone**. You've successfully completed:
- ✅ Filesystem shrunk to 425 GiB
- ✅ Partitions resized to fit 500GB target
- ✅ All data verified and accessible

## Clonezilla Clone Procedure

### 1. **Connect Target 500GB Disk**
   - Connect your 500GB disk to the system
   - Boot Clonezilla Live USB

### 2. **Clonezilla Settings**
   - Select: **device-device** clone mode
   - Select: **disk_to_local_disk**
   - Source disk: **nvme0n1** (931.5 GB)
   - Target disk: **sda** (or whatever the 500GB appears as - **verify carefully!**)

### 3. **CRITICAL: Expert Mode Settings**
   - Switch to **Expert mode**
   - Enable flag: **`-icds`** (ignore disk size check - allows larger to smaller)
   - **Do NOT** enable `-k1` (we already sized the partitions correctly)
   - Keep other defaults

### 4. **Start Clone**
   - Estimated time: 2-4 hours
   - Monitor for errors

### 5. **After Clone Completes**
   - Boot back into this NixOS system (not the cloned disk yet)
   - Come back to Claude - we'll complete Phase 6 together

## What We'll Do in Phase 6 (Post-Clone)
When you return:
1. Mount the cloned disk
2. Update `/etc/fstab` with new UUIDs
3. Reinstall GRUB on the target disk
4. Regenerate initramfs
5. Test boot from new disk

## Important Notes
- ⚠️ **Double-check target disk selection** - Clonezilla will erase it!
- The clone will copy the entire 452 GiB layout to the 500GB disk
- You'll have ~13 GiB free space on the new disk after clone

## Source Disk Final State
- Device: /dev/nvme0n1 (Samsung 990 PRO 1TB)
- Partition 1: 66.7 MB (BIOS boot)
- Partition 2: 435 GiB (btrfs, UUID: 8590c09a-138e-4615-b02d-c982580e3bf8)
- Partition 3: 16.7 GiB (swap, UUID: 549e5677-dc32-4b89-81c7-1c83b3eed996)
- Total used: 452 GiB

**Ready to start Clonezilla!** Return here when the clone is complete for Phase 6.
