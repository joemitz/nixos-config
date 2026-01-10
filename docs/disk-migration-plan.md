# Disk Migration Plan

## Pre-Clone
1. Boot Clonezilla live USB
2. Select disk-to-disk clone
3. Source: current system disk
4. Destination: new larger disk
5. Enable partition resizing to fill new disk
6. Start clone and wait for completion

## Post-Clone
1. Shut down (don't reboot)
2. Physically remove or disconnect old disk
3. Enter BIOS/UEFI and set new disk as primary boot device
4. Boot into NixOS from new disk

## After First Boot
```bash
# Expand Btrfs filesystem to use new space
sudo btrfs filesystem resize max /

# Verify it worked
df -h /
sudo btrfs filesystem show /

# Run verification script
cd ~/nixos-config/migration
./post-clone-verify.sh
```

## Critical Points
- **Must remove old disk before booting** (prevents duplicate label conflicts)
- Labels are preserved, no config changes needed
- All subvolumes automatically share the expanded space
- Can resize while booted and using the system
