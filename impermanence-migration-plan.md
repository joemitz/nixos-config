# Impermanence Migration Plan
## Ephemeral Root with Btrfs Blank Snapshot Strategy

### Goal
Implement root impermanence where the root filesystem is wiped on every boot, ensuring complete system reproducibility. Only explicitly declared state persists.

---

## Current State

**Existing Subvolumes:**
- `@` - Root filesystem (will become ephemeral)
- `@home` - User home directories (already persistent)
- `@nix` - Nix store (already persistent)

**Target State:**
- `@root-blank` - Empty template (never mounted)
- `@root` - Ephemeral root (restored from blank on each boot)
- `@nix` - Nix store (persistent)
- `@persist` - System state that must survive (NEW)
- `@home` - User data (persistent)

---

## SAFETY FIRST: Backup and Rollback Strategy

### Critical Safety Measure

**BEFORE making any changes to subvolumes, we create a backup snapshot of your current working @ subvolume.**

This ensures you can always return to your current working system if anything goes wrong.

### Safety Backup (Do This Before Phase 3)

```bash
# From live USB, after mounting Btrfs root
sudo mount -o subvolid=5 /dev/sda2 /mnt/btrfs

# Create timestamped backup of current working @
sudo btrfs subvolume snapshot /mnt/btrfs/@ /mnt/btrfs/@-backup-$(date +%Y%m%d)

# Verify backup exists
sudo btrfs subvolume list /mnt/btrfs | grep backup
# Should show: ID XXX gen XXX top level 5 path @-backup-YYYYMMDD
```

**This @-backup snapshot is your safety net.** Keep it indefinitely until you're 100% confident with impermanence.

### Rollback Procedures

#### Option 1: Quick Rollback (Boot Previous Generation)

If something breaks after configuration changes:
1. **Reboot** and at systemd-boot menu, select previous generation
2. System boots with old config (before impermanence changes)
3. Remove impermanence from configuration.nix and rebuild

#### Option 2: Full Rollback (Restore Original @ Subvolume)

If you need to completely abandon impermanence and return to original @:

**From NixOS Live USB:**
```bash
# 1. Mount Btrfs root
sudo mount -o subvolid=5 /dev/sda2 /mnt/btrfs
cd /mnt/btrfs

# 2. Move broken/current root out of the way
sudo mv @ @-broken-$(date +%Y%m%d)
# Or if you renamed to @root:
sudo mv @root @root-broken-$(date +%Y%m%d)

# 3. Restore original @ from backup snapshot
sudo btrfs subvolume snapshot @-backup-YYYYMMDD @

# 4. Update hardware-configuration.nix to use @
sudo mount -o subvol=@home /dev/sda2 /mnt/home
sudo nano /mnt/home/joemitz/nixos-config/hardware-configuration.nix
# Change any "subvol=@root" back to "subvol=@"

# 5. Unmount and reboot
sudo umount /mnt/home
sudo umount /mnt/btrfs
sudo reboot
```

**Result:** System boots exactly as it was before impermanence migration started.

### When to Delete Backup

Only delete @-backup after:
- [ ] New system (with @root and impermanence) boots successfully multiple times
- [ ] All functionality verified working
- [ ] At least 1-2 weeks of stable daily use
- [ ] You're 100% confident and comfortable

**Conservative recommendation:** Keep @-backup forever (costs minimal space with Btrfs).

---

## Migration Strategy

### Phase 1: Add Persistence Layer (Safe, Reversible)

**Goal:** Add impermanence module and @persist subvolume WITHOUT enabling root wipe yet.

**Steps:**

1. **Create @persist subvolume** (from live USB or running system):
   ```bash
   sudo mount -o subvolid=5 /dev/sda2 /mnt
   sudo btrfs subvolume create /mnt/@persist
   sudo umount /mnt
   ```

2. **Add /persist mount to hardware-configuration.nix**:
   ```nix
   fileSystems."/persist" = {
     device = "/dev/disk/by-uuid/a895216b-d275-480c-9b78-04c6a00df14a";
     fsType = "btrfs";
     options = [ "subvol=@persist" "compress=zstd" "noatime" ];
   };
   ```

3. **Import impermanence.nix in configuration.nix**:
   ```nix
   imports = [
     ./hardware-configuration.nix
     ./impermanence.nix  # Add this line
   ];
   ```

4. **Rebuild and reboot**:
   ```bash
   nh os switch /home/joemitz/nixos-config
   sudo reboot
   ```

5. **Verify persistence is working**:
   ```bash
   # Check that bind mounts exist
   findmnt | grep persist

   # Create a test file
   sudo touch /var/log/impermanence-test

   # Reboot and verify it survives
   sudo reboot
   ls -la /var/log/impermanence-test  # Should still exist
   ```

**At this point:** System works normally, but persistence layer is ready. Root is NOT wiped yet.

---

### Phase 2: Prepare for Root Wipe

**Goal:** Copy essential state to @persist before enabling root wipe.

**Steps:**

1. **Copy current state to persist** (one-time migration):
   ```bash
   # SSH host keys
   sudo mkdir -p /persist/etc/ssh
   sudo cp -a /etc/ssh/ssh_host_* /persist/etc/ssh/

   # Machine ID
   sudo cp /etc/machine-id /persist/etc/

   # NixOS state
   sudo mkdir -p /persist/var/lib
   sudo cp -a /var/lib/nixos /persist/var/lib/
   sudo cp -a /var/lib/systemd /persist/var/lib/

   # Logs (optional, starts fresh if skipped)
   sudo mkdir -p /persist/var
   sudo cp -a /var/log /persist/var/

   # NetworkManager connections
   sudo mkdir -p /persist/etc/NetworkManager
   sudo cp -a /etc/NetworkManager/system-connections /persist/etc/NetworkManager/
   ```

2. **Verify permissions**:
   ```bash
   sudo ls -la /persist/etc/ssh/  # Should match /etc/ssh/
   ```

---

### Phase 3: Create Blank Snapshot

**Goal:** Create the @root-blank template and rename current @ to @root.

**IMPORTANT:** Do this from live USB to avoid filesystem in use.

**CRITICAL:** This phase modifies subvolumes - backup first!

**Steps:**

1. **Boot into NixOS live USB**

2. **Mount Btrfs root**:
   ```bash
   sudo mkdir -p /mnt/btrfs
   sudo mount -o subvolid=5 /dev/sda2 /mnt/btrfs
   cd /mnt/btrfs
   ```

3. **FIRST: Create safety backup of current working @**:
   ```bash
   # This is your safety net - do this FIRST!
   sudo btrfs subvolume snapshot @ @-backup-$(date +%Y%m%d)

   # Verify backup was created
   sudo btrfs subvolume list /mnt/btrfs | grep backup
   # Should show: ID XXX gen XXX top level 5 path @-backup-20251220

   echo "Safety backup created! You can always restore from this."
   ```

4. **Create @root from current @**:
   ```bash
   sudo btrfs subvolume snapshot @ @root
   # Verify it worked
   sudo btrfs subvolume list /mnt/btrfs | grep @root
   ```

5. **Create blank @root-blank template**:
   ```bash
   sudo btrfs subvolume create @root-blank

   # Make it truly minimal (optional but recommended)
   # The blank snapshot should be nearly empty
   ```

**After these steps, you have:**
- `@-backup-YYYYMMDD` - **SAFETY BACKUP** of original working system
- `@` - Original (can be deleted later, after verifying @root works)
- `@root` - Copy that will become ephemeral
- `@root-blank` - Empty template for wiping

5. **Update hardware-configuration.nix** (from live USB):
   ```bash
   # Mount home to edit config
   sudo mkdir -p /mnt/home
   sudo mount -o subvol=@home /dev/sda2 /mnt/home

   # Edit the file
   sudo nano /mnt/home/joemitz/nixos-config/hardware-configuration.nix
   ```

   **Change:**
   ```nix
   # OLD:
   fileSystems."/" = {
     device = "/dev/disk/by-uuid/...";
     fsType = "btrfs";
     options = [ "subvol=@" ];
   };

   # NEW:
   fileSystems."/" = {
     device = "/dev/disk/by-uuid/...";
     fsType = "btrfs";
     options = [ "subvol=@root" ];  # Changed from @ to @root
   };
   ```

6. **Unmount and reboot**:
   ```bash
   sudo umount /mnt/home
   sudo umount /mnt/btrfs
   sudo reboot
   ```

7. **Verify system boots with @root**:
   ```bash
   findmnt / | grep @root  # Should show subvol=/@root
   ```

**At this point:** System boots from @root, but root is NOT wiped yet. This is a safe intermediate state.

---

### Phase 4: Enable Root Wipe on Boot

**Goal:** Add initrd script that wipes @root and restores from @root-blank on every boot.

**CRITICAL:** This is the point of no return for each boot. Everything not in /persist, /nix, or /home will be lost.

**Add to configuration.nix**:

```nix
{
  # Wipe root on boot by restoring from blank snapshot
  boot.initrd.postDeviceCommands = lib.mkAfter ''
    mkdir /btrfs_tmp
    mount -o subvolid=5 /dev/sda2 /btrfs_tmp

    if [[ -e /btrfs_tmp/@root ]]; then
        mkdir -p /btrfs_tmp/old_roots
        timestamp=$(date --date="@$(stat -c %Y /btrfs_tmp/@root)" "+%Y%m%d_%H%M%S")
        mv /btrfs_tmp/@root "/btrfs_tmp/old_roots/$timestamp-@root"
    fi

    delete_subvolume_recursively() {
        IFS=$'\n'
        for i in $(btrfs subvolume list -o "$1" | cut -f 9- -d ' '); do
            delete_subvolume_recursively "/btrfs_tmp/$i"
        done
        btrfs subvolume delete "$1"
    }

    for i in $(find /btrfs_tmp/old_roots/ -maxdepth 1 -mtime +30); do
        delete_subvolume_recursively "$i"
    done

    btrfs subvolume snapshot /btrfs_tmp/@root-blank /btrfs_tmp/@root
    umount /btrfs_tmp
  '';
}
```

**What this does:**
1. Mounts Btrfs root volume before boot
2. Moves current @root to old_roots/ (timestamped backup)
3. Deletes old_roots older than 30 days
4. Creates fresh @root from @root-blank snapshot
5. System boots with clean root

**Rebuild and test**:
```bash
nh os switch /home/joemitz/nixos-config
sudo reboot
```

**Verify impermanence is working**:
```bash
# Create a test file that should NOT persist
sudo touch /etc/should-be-gone
sudo reboot

# After reboot, this should fail:
ls /etc/should-be-gone  # File should be gone!

# But persisted data should survive:
ls -la /var/log/  # Should have logs
ssh localhost     # SSH host key should be same
```

---

## Testing Strategy

### Safe Testing Order

1. **Test Phase 1** - Reboot several times, verify system stability with persistence layer
2. **Test Phase 2** - Verify all critical state is in /persist
3. **Test Phase 3** - Boot from @root subvolume, verify everything works
4. **Test Phase 4** - Enable root wipe, test on non-critical reboot

### Rollback Plan

**If something breaks after Phase 4:**

1. **Reboot and select previous generation** from systemd-boot menu
2. **Remove impermanence from config**:
   ```bash
   # Comment out or remove from configuration.nix:
   # - impermanence.nix import
   # - boot.initrd.postDeviceCommands
   ```
3. **Rebuild**:
   ```bash
   nh os switch /home/joemitz/nixos-config
   ```

---

## Verification Checklist

After completing all phases:

- [ ] System boots successfully
- [ ] Root filesystem is wiped (test by creating /tmp/test, rebooting, file should be gone)
- [ ] SSH host keys persist (ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub shows same fingerprint)
- [ ] Network connections persist (WiFi passwords saved)
- [ ] System logs persist (journalctl shows logs from previous boots)
- [ ] Home directory data intact (/home/joemitz/ unchanged)
- [ ] Nix store intact (nix-store --verify works)
- [ ] Can rebuild system (nh os switch works)

---

## Cleanup: Removing Old Subvolumes (Optional)

### When It's Safe to Clean Up

Only after ALL of these conditions are met:
- [ ] Impermanence has been running successfully for 1-2+ weeks
- [ ] Multiple reboots completed without issues
- [ ] All verification checklist items passed
- [ ] You're 100% confident with the new system
- [ ] @-backup-YYYYMMDD exists as ultimate safety net

### What to Delete

**Original @ subvolume** (if you kept it in Phase 3):
```bash
# From live USB or running system
sudo mount -o subvolid=5 /dev/sda2 /mnt/btrfs

# List subvolumes to confirm what exists
sudo btrfs subvolume list /mnt/btrfs

# Delete original @ (only if @root is working perfectly)
sudo btrfs subvolume delete /mnt/btrfs/@

sudo umount /mnt/btrfs
```

**Old /nix from @ subvolume** (from the @nix migration):
```bash
# If you haven't done this yet from the @nix migration
sudo mount -o subvolid=5 /dev/sda2 /mnt/btrfs
sudo rm -rf /mnt/btrfs/@root/nix  # Or @-backup-YYYYMMDD/nix if cleaning backup
sudo umount /mnt/btrfs
```

### What to KEEP Forever

**@-backup-YYYYMMDD** - Your safety snapshot
- Costs minimal space (Btrfs CoW sharing)
- Ultimate insurance policy
- Can restore entire system if catastrophic failure
- **Recommendation: Never delete this**

**@root-blank** - The blank template
- Required for impermanence to work
- Never delete this!

---

## Adding More Persistence

As you use the system, you may find you need to persist additional paths. Add them to `impermanence.nix`:

```nix
environment.persistence."/persist" = {
  directories = [
    # ... existing entries ...
    "/var/lib/bluetooth"  # Example: bluetooth pairings
  ];
};
```

Then rebuild and reboot.

---

## Benefits Achieved

Once complete:
- ✅ **True reproducibility** - System state comes from config, not accumulated cruft
- ✅ **No hidden state** - If it's not declared, it doesn't persist
- ✅ **Easy testing** - Can test config changes with confidence
- ✅ **Clean system** - No accumulated junk from experiments
- ✅ **Audit trail** - Everything that persists is explicitly declared in git

---

## References

- [Erase Your Darlings](https://grahamc.com/blog/erase-your-darlings) - Original concept
- [impermanence module](https://github.com/nix-community/impermanence) - NixOS module
- [NixOS Wiki - Impermanence](https://wiki.nixos.org/wiki/Impermanence)
