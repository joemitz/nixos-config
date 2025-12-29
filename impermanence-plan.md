# Root Impermanence Implementation Plan

## Overview
Implement root impermanence using nix-community/impermanence module with Btrfs blank snapshot rollback. Root (/) will be wiped on every boot while /home remains persistent.

## Strategy
- **Method**: Blank snapshot rollback (create @root-blank, restore on each boot)
- **Persistence**: Store persistent system state in new @persist subvolume
- **Scope**: Only / (root) ephemeral; /home, /nix remain persistent

## New Btrfs Subvolume Layout
```
/dev/sda2 (a895216b-d275-480c-9b78-04c6a00df14a)
├── @ (root - deleted and restored from @root-blank on each boot)
├── @root-blank (NEW - read-only pristine root snapshot)
├── @persist (NEW - persistent system state, mounted at /persist)
├── @snapshots (NEW - persistent Snapper snapshots of root, mounted at /.snapshots)
├── @home (existing - persistent user data)
└── @nix (existing - persistent Nix store)
```

## Critical Files to Modify

### 1. `/home/joemitz/nixos-config/flake.nix`
- Add `impermanence.url = "github:nix-community/impermanence"` to inputs
- Add `impermanence` parameter to outputs
- Add `impermanence.nixosModules.impermanence` to modules list

### 2. `/home/joemitz/nixos-config/hardware-configuration.nix`
- Add new filesystem mounts for /persist and /.snapshots:
```nix
fileSystems."/persist" = {
  device = "/dev/disk/by-uuid/a895216b-d275-480c-9b78-04c6a00df14a";
  fsType = "btrfs";
  options = [ "subvol=@persist" "compress=zstd" "noatime" ];
  neededForBoot = true;  # CRITICAL: must mount before impermanence activation
};

fileSystems."/.snapshots" = {
  device = "/dev/disk/by-uuid/a895216b-d275-480c-9b78-04c6a00df14a";
  fsType = "btrfs";
  options = [ "subvol=@snapshots" "compress=zstd" "noatime" ];
  neededForBoot = true;  # Mount early for Snapper
};
```

### 3. `/home/joemitz/nixos-config/configuration.nix`
Three major changes:

#### A. Add boot rollback service (after line 22):
```nix
boot.initrd.systemd = {
  enable = true;
  services.rollback = {
    description = "Rollback Btrfs root subvolume to blank state";
    wantedBy = [ "initrd.target" ];
    before = [ "sysroot.mount" ];
    unitConfig.DefaultDependencies = "no";
    serviceConfig.Type = "oneshot";
    script = ''
      mkdir -p /mnt
      mount -o subvolid=5 /dev/disk/by-uuid/a895216b-d275-480c-9b78-04c6a00df14a /mnt

      # Delete nested subvolumes (Snapper snapshots)
      btrfs subvolume list -o /mnt/@ | cut -f9 -d' ' | while read subvolume; do
        btrfs subvolume delete "/mnt/$subvolume" || true
      done

      # Delete root subvolume
      btrfs subvolume delete /mnt/@

      # Restore from blank snapshot
      btrfs subvolume snapshot /mnt/@root-blank /mnt/@

      umount /mnt
    '';
  };
};
```

#### B. Add persistence configuration (after sops config, around line 163):
```nix
environment.persistence."/persist" = {
  hideMounts = true;

  directories = [
    "/var/log"
    "/var/lib/nixos"
    "/var/lib/systemd/coredump"
    "/var/lib/systemd/timers"
    "/var/lib/systemd/rfkill"
    "/var/lib/docker"
    "/var/lib/NetworkManager"
    "/etc/NetworkManager/system-connections"
    "/var/lib/bluetooth"
    "/var/lib/tailscale"
    "/var/lib/cups"
    "/var/lib/fwupd"
    "/var/lib/AccountsService"
    "/var/lib/geoclue"
    "/var/lib/upower"
  ];

  files = [
    "/etc/machine-id"
    "/etc/ssh/ssh_host_ed25519_key"
    "/etc/ssh/ssh_host_ed25519_key.pub"
    "/etc/ssh/ssh_host_rsa_key"
    "/etc/ssh/ssh_host_rsa_key.pub"
    "/var/lib/systemd/random-seed"
  ];

  # Note: No users.joemitz section needed since /home is already persistent
  # via the @home subvolume mount. All user files persist automatically.
};
```

#### C. Keep Snapper configuration (no changes needed):
Snapper will continue to create snapshots for both root and home. Root snapshots will be stored in `/.snapshots` (mounted from `@snapshots` subvolume), so they persist across reboots. This allows you to manually restore to previous root states if needed.

### 4. `/home/joemitz/nixos-config/home.nix`
- Remove WebStorm PATH reference (lines 124: `PATH = lib.mkAfter "/opt/WebStorm-243.26053.12/bin:$PATH";`)

## Implementation Steps

### Phase 1: Configuration Changes
1. Backup SSH keys: `sudo cp -r /etc/ssh ~/ssh-backup`
2. Take Btrfs snapshot backup: `sudo btrfs subvolume snapshot / /mnt/backup-before-impermanence`
3. Modify flake.nix (add impermanence input and module)
4. Modify configuration.nix (add rollback service, persistence config, remove Snapper root)
5. Modify hardware-configuration.nix (add /persist mount)
6. Modify home.nix (remove WebStorm PATH)
7. Test: `nix flake check`
8. Test: `nixos-rebuild dry-build`

### Phase 2: Create Btrfs Subvolumes (Live Boot Required)
**Must boot from NixOS live USB** (cannot modify mounted root subvolume)

```bash
# Boot from live USB, then:
mkdir /mnt/btrfs-root
mount -o subvolid=5 /dev/disk/by-uuid/a895216b-d275-480c-9b78-04c6a00df14a /mnt/btrfs-root

# Create persistent storage subvolume
btrfs subvolume create /mnt/btrfs-root/@persist

# Create snapshots storage subvolume
btrfs subvolume create /mnt/btrfs-root/@snapshots

# Create read-only blank snapshot of current root
btrfs subvolume snapshot -r /mnt/btrfs-root/@ /mnt/btrfs-root/@root-blank

# Verify (should see @persist, @snapshots, @root-blank as new subvolumes)
btrfs subvolume list /mnt/btrfs-root

# Unmount
umount /mnt/btrfs-root
```

### Phase 3: First Boot
1. Reboot into system
2. Watch boot logs: `journalctl -b | grep rollback`
3. Verify mounts:
   - `mount | grep persist` (should show /persist)
   - `mount | grep snapshots` (should show /.snapshots)
4. Check services: `systemctl status sshd docker tailscaled NetworkManager`
5. Test SSH from remote machine (verify no host key warnings)
6. Test Docker: `docker ps`
7. Test Tailscale: `tailscale status`
8. Verify Snapper: `sudo snapper -c root list` (should show root snapshots)

### Phase 4: Validation
1. Create test file in /: `sudo touch /root/test-ephemeral.txt`
2. Create test file in /persist: `sudo touch /persist/test-persistent.txt`
3. Create Snapper snapshot: `sudo snapper -c root create --description "Test snapshot"`
4. Verify snapshot exists: `sudo snapper -c root list`
5. Reboot
6. Verify /root/test-ephemeral.txt is GONE
7. Verify /persist/test-persistent.txt EXISTS
8. Verify snapshot persisted: `sudo snapper -c root list` (should still show test snapshot)
9. Run full workflow tests (Android dev, Docker, networking, secrets)

## What Gets Persisted

### System Critical
- `/etc/machine-id` - Systemd identity
- `/etc/ssh/ssh_host_*` - SSH host keys (prevents trust warnings)
- `/var/lib/systemd/random-seed` - Crypto entropy

### Services & State
- `/var/log` - System logs
- `/var/lib/nixos` - NixOS user/group state
- `/var/lib/docker` - Docker images/containers
- `/var/lib/NetworkManager` - WiFi passwords
- `/var/lib/bluetooth` - Bluetooth pairings
- `/var/lib/tailscale` - VPN identity
- `/var/lib/AccountsService` - Display manager metadata

### Already Persistent (No Action Needed)
- `/home` - **Entire home directory** (mounted from @home subvolume)
  - All user files automatically persist: `.bash_history`, `Android/`, `.gradle`, `.config/*`, etc.
- `/nix` - Nix store (mounted from @nix subvolume)
- `/boot` - EFI partition
- `~/.config/sops/age/keys.txt` - Sops encryption key (in /home)
- `~/.config/secrets.env` - Secrets file (in /home, regenerated on boot)

## Rollback Plan

### Emergency: Skip Rollback Service
At boot, interrupt and disable rollback:
```bash
systemctl mask rollback.service
```
System boots into last state before rollback.

### Restore from Snapper Snapshot
If you have a good Snapper snapshot of root, you can restore it:
```bash
# Boot from live USB
mkdir /mnt/btrfs-root
mount -o subvolid=5 /dev/disk/by-uuid/a895216b-d275-480c-9b78-04c6a00df14a /mnt/btrfs-root

# List available snapshots
ls /mnt/btrfs-root/@snapshots/*/snapshot

# Delete current @ subvolume
btrfs subvolume delete /mnt/btrfs-root/@

# Restore from Snapper snapshot (replace NUMBER with snapshot number)
btrfs subvolume snapshot /mnt/btrfs-root/@snapshots/NUMBER/snapshot /mnt/btrfs-root/@

# Reboot
umount /mnt/btrfs-root
```

### Restore from Backup
```bash
# Boot from live USB
mount -o subvolid=5 /dev/disk/by-uuid/a895216b-d275-480c-9b78-04c6a00df14a /mnt
btrfs subvolume delete /mnt/@
btrfs subvolume snapshot /mnt/backup-before-impermanence /mnt/@
# Reboot
```

### Rollback NixOS Generation
```bash
nixos-rebuild switch --rollback
```
Then remove impermanence from flake.nix and rebuild.

## Complete Revert & Recovery Guide

This section provides detailed recovery procedures for every stage of implementation.

### Recovery by Implementation Phase

#### **Phase 1: After Config Changes (Before Reboot)**
**Safest point - nothing has changed on disk yet**

```bash
# Option 1: Git revert
cd ~/nixos-config
git log  # Find the commit before your changes
git reset --hard <commit-hash>

# Option 2: NixOS generation rollback
nixos-rebuild switch --rollback

# Option 3: Manual undo
# Just revert your edits in flake.nix, configuration.nix, hardware-configuration.nix
```

**Risk Level**: None - no system changes yet

---

#### **Phase 2: After Creating Subvolumes (Before First Boot)**
**Subvolumes exist but aren't mounted/used yet**

```bash
# Boot from live USB
mount -o subvolid=5 /dev/disk/by-uuid/a895216b-d275-480c-9b78-04c6a00df14a /mnt

# Delete new subvolumes
btrfs subvolume delete /mnt/@persist
btrfs subvolume delete /mnt/@snapshots
btrfs subvolume delete /mnt/@root-blank

# Revert config files (see Phase 1 options)
umount /mnt
```

**Risk Level**: Very low - your system hasn't booted with new config yet

---

#### **Phase 3: System Won't Boot**
**Most critical scenario**

**Option A: Boot Previous Generation (Easiest)**
1. At boot menu (systemd-boot), select previous generation
2. Once booted: `nixos-rebuild switch --rollback`
3. Remove impermanence changes from config files
4. Rebuild: `nhs`

**Option B: Live USB Recovery**
```bash
# Boot from NixOS live USB
mkdir /mnt/btrfs-root
mount -o subvolid=5 /dev/disk/by-uuid/a895216b-d275-480c-9b78-04c6a00df14a /mnt/btrfs-root

# Restore from backup snapshot we made in Phase 1
btrfs subvolume delete /mnt/btrfs-root/@
btrfs subvolume snapshot /mnt/btrfs-root/backup-before-impermanence /mnt/btrfs-root/@

# Mount the system
mount -o subvol=@ /dev/disk/by-uuid/a895216b-d275-480c-9b78-04c6a00df14a /mnt
mount -o subvol=@home /dev/disk/by-uuid/a895216b-d275-480c-9b78-04c6a00df14a /mnt/home
mount -o subvol=@nix /dev/disk/by-uuid/a895216b-d275-480c-9b78-04c6a00df14a /mnt/nix
mount /dev/disk/by-uuid/F2B1-6D81 /mnt/boot

# Chroot and fix
nixos-enter --root /mnt
cd /home/joemitz/nixos-config
git reset --hard <previous-commit>
nixos-rebuild switch

# Reboot
exit
reboot
```

**Risk Level**: Medium - but fully recoverable with backup snapshot

---

#### **Phase 4: System Boots But Something Broken**
**Services don't work, data missing, etc.**

**Option A: Temporarily Disable Rollback**
```bash
# This boots into the current @ state (before rollback happens)
sudo systemctl mask initrd-rollback.service
reboot

# Fix issues, then re-enable
sudo systemctl unmask initrd-rollback.service
```

**Option B: Boot Previous Generation**
Select previous generation from boot menu → rollback config

**Option C: Keep Impermanence But Fix Config**
```bash
# Fix the persistence config to include missing files/directories
# Edit configuration.nix to add missing paths
nhs  # Rebuild and commit
reboot  # Test
```

**Risk Level**: Low - system is functional, just needs tuning

---

### Nuclear Option: Complete System Recovery

If everything goes wrong and you can't boot anything:

```bash
# Boot from NixOS live USB
mount -o subvolid=5 /dev/disk/by-uuid/a895216b-d275-480c-9b78-04c6a00df14a /mnt

# Your data is safe:
# - /home in @home subvolume (untouched)
# - /nix in @nix subvolume (untouched)
# - Config repo in /home (untouched)

# Delete broken root, restore backup
btrfs subvolume delete /mnt/@
btrfs subvolume snapshot /mnt/backup-before-impermanence /mnt/@

# Delete impermanence subvolumes
btrfs subvolume delete /mnt/@persist
btrfs subvolume delete /mnt/@snapshots
btrfs subvolume delete /mnt/@root-blank

# Mount and fix config
mount -o subvol=@ /dev/disk/by-uuid/a895216b-d275-480c-9b78-04c6a00df14a /mnt
mount -o subvol=@home /dev/disk/by-uuid/a895216b-d275-480c-9b78-04c6a00df14a /mnt/home
mount -o subvol=@nix /dev/disk/by-uuid/a895216b-d275-480c-9b78-04c6a00df14a /mnt/nix
mount /dev/disk/by-uuid/F2B1-6D81 /mnt/boot

nixos-enter --root /mnt
cd /home/joemitz/nixos-config
git reset --hard <before-impermanence>
nixos-rebuild switch
exit
reboot
```

---

### What CAN'T Be Lost

✅ **Guaranteed Safe:**
- Your entire `/home` directory (on separate @home subvolume)
- All Nix store packages (on separate @nix subvolume)
- Your config repo (in /home)
- Your SSH keys (backed up before starting + in /home)
- Boot partition (not touched)
- Backup snapshot (unless you manually delete it)
- All your development work, code, and personal files

❌ **Could Be Lost if You Don't Revert:**
- Changes made to `/` after implementing impermanence (but that's the point!)
- System state not in persistence config (but recoverable from backup)
- Temporary files and caches (intentionally ephemeral)

---

### Critical Safety Measures

The implementation includes multiple safety nets:

1. **Backup snapshot before starting** (Phase 1, step 2):
   - Creates `backup-before-impermanence` subvolume
   - Your golden rollback point
   - Can restore to exact pre-impermanence state

2. **SSH keys backup** (Phase 1, step 1):
   - Saved to `~/ssh-backup`
   - Can manually restore if needed

3. **Previous NixOS generations**:
   - Always available in boot menu
   - Can boot any previous working generation
   - Unaffected by impermanence changes

4. **Separate persistent subvolumes**:
   - `/home` on @home (never touched)
   - `/nix` on @nix (never touched)
   - `/boot` on separate partition (never touched)

5. **Git version control**:
   - All config changes tracked in git
   - Can revert to any previous commit
   - Repo lives in persistent /home

---

### Quick Reference: Recovery Decision Tree

```
Can't boot?
├─ YES → Boot from previous NixOS generation (Option A)
│        OR boot from live USB (Option B)
│
└─ NO → System boots but broken?
    ├─ YES → Missing files/services?
    │        ├─ Add to persistence config → rebuild
    │        └─ OR temporarily disable rollback → investigate
    │
    └─ NO → Want to completely revert?
             └─ Use Nuclear Option (live USB + restore backup)
```

---

### Bottom Line

Your data in `/home` is **never at risk**. You always have:
- The backup snapshot
- Previous NixOS generations
- Persistent /home, /nix, and /boot
- Git history of all config changes

Worst case scenario: 30 minutes booting from live USB to restore the backup snapshot. Everything returns to pre-impermanence state with zero data loss.

## Risk Mitigations

### High Priority
- ✅ SSH host keys backed up and persisted
- ✅ /etc/machine-id persisted (required by many services)
- ✅ Tailscale state persisted (avoids re-authentication)
- ✅ Docker state persisted (avoids rebuilding containers)
- ✅ /persist mounts with `neededForBoot = true`

### Known Issues Addressed
- ✅ Snapper root snapshots persist via separate @snapshots subvolume
- ✅ Snapper home config kept (home remains persistent)
- ✅ WebStorm removed (not used)
- ✅ Sops age key in /home (already persistent)
- ✅ Git repo in /home (nhs alias continues working)

## Post-Implementation Checklist
- [ ] System boots without errors
- [ ] Rollback service runs successfully in initrd
- [ ] /persist is mounted
- [ ] /.snapshots is mounted
- [ ] SSH works remotely without host key warnings
- [ ] Tailscale connected
- [ ] Docker containers accessible
- [ ] WiFi connections persist after reboot
- [ ] Bluetooth devices remain paired
- [ ] Secrets loaded: `env | grep NPM_TOKEN`
- [ ] Test file in / disappears after reboot
- [ ] Test file in /persist survives reboot
- [ ] Snapper root snapshots persist after reboot
- [ ] `nhs` alias works for auto-commit

## Benefits
- Clean system state on every boot (no cruft accumulation)
- Truly declarative system (only declared state persists)
- Easy recovery (always boots from known-good @root-blank)
- Confidence in configuration reproducibility
- Persistent root snapshots via Snapper (manual recovery to previous states)
- Best of both worlds: ephemeral by default, recoverable when needed

## Time Estimate
- Configuration changes: 1-2 hours
- Live boot subvolume creation: 30-60 minutes
- Testing and validation: 2-3 hours
- **Total: 4-6 hours**
