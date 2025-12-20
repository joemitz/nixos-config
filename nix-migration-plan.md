# Migration Plan: Add @nix Btrfs Subvolume

## MIGRATION STATUS (2025-12-20)

**Phase 1: COMPLETED** - Pre-migration checkpoint committed (f312ea0)

**Phase 2: COMPLETED** - Live USB data migration successful:
- @nix subvolume created (ID 263)
- All 693,297 files copied using reflinks (CoW)
- Verified: No data duplication (reflinks working correctly)
- Note: Could not unmount /mnt/btrfs-root because Claude Code running from mounted directory

**NEXT STEP: Start Phase 3** - Edit hardware-configuration.nix to add /nix mount entry

The @nix subvolume now contains a complete copy of the Nix store. On next boot after config update, the system will mount /nix from the new @nix subvolume instead of using the old /nix directory in @ subvolume.

---

## Overview

Migrate `/nix` (currently 21GB inside `@` subvolume) to a dedicated `@nix` Btrfs subvolume on `/dev/sda2`. This follows NixOS best practices and enables independent snapshot management, optimized mount options, and prevents snapshots from including the massive Nix store.

## Current State

- `/dev/sda2` has two subvolumes: `@` (root) and `@home` (home directories)
- `/nix` currently resides inside `@` (no separate subvolume)
- System: 476GB total, 46GB used, 429GB available
- Boot: systemd-boot on `/dev/sda1` (EFI)
- 30 boot generations available for rollback

## Why This Matters

**Benefits of separate @nix subvolume:**
- Snapshots of root won't include 21GB+ Nix store (wasteful)
- Enable Nix-optimized mount options: `compress=zstd` (saves 20-40% space) and `noatime` (reduces writes)
- Independent management of Nix store separate from system config
- Matches standard NixOS + Btrfs best practices

**Current issue:** Any Btrfs snapshot of `/` includes the entire Nix store unnecessarily.

## Migration Strategy

**Safe approach using Live USB + reflink copies:**
1. Boot from NixOS live USB (safest - no processes using /nix)
2. Create `@nix` subvolume at Btrfs root level
3. Copy data using `cp --reflink=always` (CoW copy, no space duplication)
4. Update `hardware-configuration.nix` with new mount entry
5. Reboot and test new generation
6. Clean up old /nix from @ subvolume after verification

**Alternative: Single-user/rescue mode** (riskier but no USB needed)

## Accessing Claude Code in Live USB Environment

You'll want Claude Code available in the live environment to help execute the migration steps. Here are three options:

### Option 1: Temporary nix-shell (Easiest - Recommended)

Once booted into the live USB, open a terminal and run:

```bash
# Quick temporary shell with claude-code
nix-shell -p claude-code

# This will download and make claude-code available
# Then you can run: claude
```

This is the fastest way to get claude-code without any setup.

### Option 2: Use Your Existing Flake Configuration

After mounting your partitions in Phase 2, you can access your nixos-config:

```bash
# Mount your home partition
mkdir -p /mnt/home
mount -o subvol=@home /dev/sda2 /mnt/home

# Navigate to your config
cd /mnt/home/joemitz/nixos-config

# Run claude-code from the flake input
nix run github:sadjow/claude-code-nix

# Or enter a dev shell with all your tools
nix develop
```

This uses your existing flake configuration and gives you the same claude-code version you use on your main system.

### Option 3: Build Custom Live USB with Claude Code (Not Recommended)

This would require building a custom NixOS ISO with claude-code pre-installed:

```bash
# Create a custom ISO configuration
# Add claude-code to systemPackages
# Build with: nix build .#nixosConfigurations.liveUSB.config.system.build.isoImage

# Time required: 20-40 minutes
# Complexity: High
# Benefit: Claude Code available immediately on boot
```

**Not recommended for this migration** - Options 1 or 2 are much faster and simpler.

### Recommended Approach

Use **Option 1** when you first boot the live USB:
1. Boot into NixOS live USB GUI
2. Open Konsole (terminal)
3. Run: `nix-shell -p claude-code`
4. Wait for download (~1-2 minutes)
5. Run: `claude` to start
6. Follow this plan file for migration steps

## Implementation Steps

### Phase 1: Preparation (Current System)

**Verify system health:**
```bash
# Check Btrfs filesystem health
sudo btrfs scrub start /
sudo btrfs scrub status /

# Document current state
sudo btrfs subvolume list / > ~/subvolumes-before.txt
mount | grep btrfs > ~/mounts-before.txt

# Verify current generation boots
nixos-rebuild list-generations | tail -5

# Commit any uncommitted config changes
cd /home/joemitz/nixos-config
git status
git add -A && git commit -m "pre-migration checkpoint"
git push
```

**Create backups:**
- Current git config is already version controlled
- Document current boot generation number (currently 29)
- Verify previous generation available for rollback

### Phase 2: Create Subvolume and Migrate Data (Live USB Environment)

**Boot NixOS live USB, then:**

```bash
# Mount Btrfs root (subvolid=5 is the top-level volume)
mkdir -p /mnt/btrfs-root
mount -o subvolid=5 /dev/sda2 /mnt/btrfs-root

# Create @nix subvolume at root level
cd /mnt/btrfs-root
btrfs subvolume create @nix

# Verify creation
btrfs subvolume list /mnt/btrfs-root | grep @nix
# Should show: ID [XXX] gen [XXX] top level 5 path @nix

# Mount source (@) and destination (@nix)
mkdir -p /mnt/source /mnt/dest
mount -o subvol=@ /dev/sda2 /mnt/source
mount -o subvol=@nix /dev/sda2 /mnt/dest

# Copy /nix using reflinks (CoW copy - fast, no space duplication)
cp -ax --reflink=always /mnt/source/nix/* /mnt/dest/
# -a = archive mode (preserve permissions, ownership, timestamps)
# -x = stay on same filesystem
# --reflink=always = use CoW, fail if not possible

# Verify copy success
echo $?  # Should be 0
diff -r /mnt/source/nix /mnt/dest --brief | head -20
# Should show no differences

# Verify file counts match
find /mnt/source/nix -type f | wc -l
find /mnt/dest -type f | wc -l
# Counts should be identical

# Verify no space duplication (reflinks working)
btrfs filesystem df /mnt/btrfs-root
# Data usage should NOT have doubled

# Unmount before reboot
sync
umount /mnt/dest /mnt/source /mnt/btrfs-root
```

### Phase 3: Update Configuration (Live USB or After Reboot)

**Edit `/home/joemitz/nixos-config/hardware-configuration.nix`:**

Add after the `/home` mount entry (after line 26):

```nix
  fileSystems."/nix" =
    { device = "/dev/disk/by-uuid/a895216b-d275-480c-9b78-04c6a00df14a";
      fsType = "btrfs";
      options = [ "subvol=@nix" "compress=zstd" "noatime" ];
    };
```

**Mount options explained:**
- `subvol=@nix` - Mount the new @nix subvolume
- `compress=zstd` - Transparent compression (20-40% space savings, fast)
- `noatime` - Don't update access times (reduces writes, Nix doesn't need it)

**If editing from live USB:**
```bash
# Mount config directory
mount -o subvol=@home /dev/sda2 /mnt
nano /mnt/joemitz/nixos-config/hardware-configuration.nix
# Add the /nix mount entry
umount /mnt
```

### Phase 4: Rebuild and Test (After Rebooting to Normal System)

```bash
cd /home/joemitz/nixos-config

# Build without switching (test configuration)
sudo nixos-rebuild build --flake .#nixos
# Check for errors - should succeed

# Switch to new generation
nh os switch /home/joemitz/nixos-config
# Will create new generation (30 or 31) with /nix mount

# Verify boot entry created
sudo ls -la /boot/loader/entries/ | tail -3

# REBOOT to test
sudo reboot
```

**After reboot, verify:**
```bash
# Verify /nix mounted as separate subvolume
mount | grep /nix
# Should show: /dev/sda2 on /nix type btrfs (rw,noatime,compress=zstd,...)

# Verify correct subvolume
findmnt /nix
# Should show: subvol=/@nix

# Test Nix store integrity
ls -la /nix/store/ | head
nix-store --verify --check-contents

# Test Nix operations work
nix-shell -p hello --run hello

# Test NH rebuild
nh os switch /home/joemitz/nixos-config

# Check system health
systemctl --failed
```

### Phase 5: Cleanup (ONLY After Successful Verification)

**Wait at least 24 hours and multiple reboots before cleanup!**

```bash
# Mount Btrfs root
sudo mkdir -p /mnt/btrfs-root
sudo mount -o subvolid=5 /dev/sda2 /mnt/btrfs-root

# Verify old /nix exists in @ subvolume
ls -la /mnt/btrfs-root/@/nix

# Remove old /nix (21GB freed after balance)
sudo rm -rf /mnt/btrfs-root/@/nix

# Unmount
sudo umount /mnt/btrfs-root

# Check space reclaimed
df -h /
sudo btrfs filesystem df /
```

### Phase 6: Finalize

```bash
cd /home/joemitz/nixos-config

# Commit the configuration change
git add hardware-configuration.nix
git commit -m "add @nix btrfs subvolume for nix store"
git push
```

## Rollback Procedures

### If boot fails after configuration change:

1. **At systemd-boot menu:** Select previous generation (29 or earlier)
2. **After successful boot:**
   ```bash
   cd /home/joemitz/nixos-config
   git revert HEAD  # Undo hardware-configuration.nix changes
   nh os switch /home/joemitz/nixos-config
   ```

### If /nix mount fails but system boots:

```bash
# Emergency mount
sudo mkdir -p /nix
sudo mount -o subvol=@nix,compress=zstd,noatime /dev/sda2 /nix

# Verify works, then rebuild
nix-store --verify
nh os switch /home/joemitz/nixos-config
```

### If data corruption detected:

1. Boot from live USB
2. Mount both @ and @nix subvolumes
3. If old /nix still exists in @, copy back to @nix
4. Or delete @nix and start migration over

## Safety Checks

**Before starting:**
- [ ] Current system boots successfully
- [ ] At least 2 working boot generations available
- [ ] Btrfs filesystem healthy (scrub passes)
- [ ] Config changes committed and pushed to git
- [ ] Live USB available and tested
- [ ] Understand systemd-boot menu navigation
- [ ] 2-4 hours allocated for process

**After migration:**
- [ ] `/nix` mounted with correct subvolume and options
- [ ] `nix-store --verify --check-contents` passes
- [ ] NH rebuilds work
- [ ] System services all running
- [ ] Multiple reboots successful
- [ ] Space not duplicated (reflinks worked)

## Critical Files Modified

- `/home/joemitz/nixos-config/hardware-configuration.nix` - Add /nix mount entry at line 27

## Timeline

- **Preparation:** 15-30 min
- **Boot live USB + create subvolume:** 5 min
- **Copy data (reflinks):** 5-15 min
- **Update config:** 10 min
- **Rebuild + test:** 10-20 min
- **Verification:** 10 min
- **Cleanup (later):** 10 min

**Total:** 65-100 minutes active time

## Web Research Sources

- [Btrfs - Official NixOS Wiki](https://wiki.nixos.org/wiki/Btrfs)
- [Nix store and Btrfs snapshots - NixOS Discourse](https://discourse.nixos.org/t/nix-store-and-btrfs-snapshots/32550)
- [Persistent btrfs subvolume mounting - NixOS Discourse](https://discourse.nixos.org/t/persistent-btrfs-subvolume-mounting/30021)
- [Subvolumes — BTRFS documentation](https://btrfs.readthedocs.io/en/latest/Subvolumes.html)
- [btrfs-migrate-folder-to-subvolume script](https://github.com/chrimic/btrfs-migrate-folder-to-subvolume)
- [Installing NixOS with Btrfs Subvolumes](https://mieszkocichon.eu/2025/09/30/installing-nixos-with-full-disk-encryption-lvm-and-btrfs-subvolumes/)

## Key Insights from Research

1. **Cannot convert directory to subvolume directly** - Must create new subvolume and migrate data
2. **Use reflinks for migration** - `cp --reflink=always` creates CoW copies (no space duplication)
3. **Best practice mount options** - `compress=zstd,noatime` for Nix store
4. **NixOS generation rollback** - Built-in safety mechanism if boot fails
5. **Subvolumes are top-level** - Not included in parent snapshots, can manage independently
