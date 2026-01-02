# Home Impermanence Implementation Plan

## Overview
Implement home directory impermanence by wiping `/home` (directory on @ subvolume) on every boot and restoring persistent data from two new subvolumes: `@persist-dotfiles` for configuration files and `@persist-userfiles` for user documents/projects.

## Architecture

### Current State
- `@home` subvolume mounted at `/home` with `neededForBoot = true` (fully persistent)
- Root impermanence working: `@` wiped on boot, recreated from `@root-blank`
- System state persisted via `@persist` with impermanence module bind mounts

### Target State
```
Btrfs Filesystem (a895216b-d275-480c-9b78-04c6a00df14a)
├── @                      (/) - WIPED ON BOOT, contains /home directory
├── @blank                 Empty reference snapshot (renamed from @root-blank)
├── @home                  REMOVED - no longer needed, /home lives on @
├── @home-backup           Safety backup of current @home before migration     ← NEW (temporary)
├── @nix                   (/nix) - Persistent
├── @persist-root          (/persist-root) - Persistent (system state)        ← RENAMED, has snapshots
├── @persist-dotfiles      (/persist-dotfiles) - Persistent (user dotfiles)   ← NEW, has snapshots
├── @persist-userfiles     (/persist-userfiles) - Persistent (user files)     ← NEW, has snapshots
└── @snapshots             REMOVED - no longer needed                           ← CHANGE
```

**Key simplifications:**
1. No separate @home subvolume - /home is just a directory on @ that gets wiped
2. Renamed @persist → @persist-root for consistent naming
3. **Removed @snapshots subvolume** - only snapshot the persist subvolumes (data that actually persists!)
4. Disabled Snapper for root and home - they're wiped on boot, snapshots are useless

## Persistence Strategy

### Dotfiles → @persist-dotfiles (mounted at /persist-dotfiles)
Any path starting with `.` goes here. Bind mounted to `/home/joemitz/.<name>`.

**Critical (must persist):**
- `.ssh/` (SSH keys, known_hosts) - CRITICAL for remote access
- `.git-credentials` - Git credential store
- `.claude/` (45M) - Claude Code data
- `.claude.json`, `.claude.json.backup` - Claude config
- `.config/` (1.4G) - Application configurations
  - Specific subdirs: `alacritty/`, `kate/`, `git/`, `gh/`, `borg/`, `sops/` (CRITICAL!), `environment.d/`, `gtk-3.0/`, `gtk-4.0/`, `guvcview2/`, `micro/`, KDE configs
- `.local/share/` (469M) - User application data
  - Use narrow paths: `applications/`, `keyrings/`, `konsole/`, `kwalletd/`, etc.
- `.local/state/` (688K) - Application state
  - Use narrow paths: `wireplumber/`, etc.
- `.android/` (515M) - Android Studio settings + AVDs
- `.mozilla/` (378M) - Firefox profiles
- `.var/` (8.2M) - Flatpak app data
- `.vscode-oss/` - VSCodium settings
- `.zoom/` (109M) - Zoom settings
- `.bashrc`, `.bash_profile`, `.profile` - Shell configs
- `.bash_history`, `.bash_history_persistent` - Command history
- `.gtkrc-2.0`, `.gtkrc` - GTK config
- `.npmrc` - NPM config
- `.pki/` - Certificate store
- `.icons/` - Icon themes

**Build caches (persist for performance):**
- `.gradle/` (3.7G) - Gradle build cache
- `.npm/` (226M) - NPM package cache
- `.cargo/` (344M) - Rust toolchain cache
- `.compose-cache/` - Docker compose cache
- `.java/` - Java settings/cache
- `.react-native-cli/` - React Native CLI data
- `.crashlytics/` - Crashlytics cache
- `.nix-defexpr/`, `.nix-profile/` - Nix user environment

**Selective caching:**
- `.cache/nix` (198M) - Persist (expensive to rebuild)
- `.cache/borg` (84M) - Persist (backup cache)
- `.cache/node-gyp` (64M) - Persist (native module builds)
- DO NOT persist: `.cache/mozilla`, `.cache/Google`, `.cache/thumbnails`, `.cache/plasma_theme_*`, `.cache/mesa_shader_cache` (ephemeral, auto-regenerated)

**Total dotfiles size estimate:** ~8-9 GB (with selective caching)

### Userfiles → @persist-userfiles (mounted at /persist-userfiles)
Non-dotfile directories. Bind mounted to `/home/joemitz/<name>`.

- `Android/` - Android SDK (~GB, as user requested)
- `anova/` - Project directory
- `nixos-config/` - NixOS configuration repo
- `Desktop/` - Desktop files
- `Documents/` - Documents
- `Downloads/` - Downloads
- `Pictures/` - Pictures
- `Videos/` - Videos
- `Music/` - Music
- `Templates/` - File templates
- `Public/` - Public share
- `Postman/` - Postman collections
- `Library/` - macOS-style library
- `misc/` - Miscellaneous files
- `ssh-backup/` - SSH backup folder

**Total userfiles size estimate:** Varies (depends on projects/media)

### What Gets Wiped
Anything in `/home/joemitz/` not covered by the persistence lists above will be wiped on every boot. This is intentional - only explicitly declared state persists.

## Implementation Phases

### Phase 1: Preparation & Enumeration (Current System)
**Status: Ready to execute**

#### Step 1.1: Create Branch
```bash
cd ~/nixos-config
git checkout -b home-impermanence
git push -u origin home-impermanence
```

This keeps the experimental work isolated from your main branch. You can merge it back to main after successful testing.

#### Step 1.2: Information Gathering
No code changes needed. Information gathering complete.

---

### Phase 2: Create Subvolumes & Migrate Data (Live USB Required)

⚠️ **CRITICAL: BACKUP YOUR ENTIRE DISK FIRST!** ⚠️

Before proceeding with ANY changes, create a full disk image with Clonezilla:
1. Boot Clonezilla Live USB
2. Choose "device-image" mode
3. Save entire disk image to external drive
4. Verify the backup completed successfully
5. Keep this backup until you've verified the new setup works perfectly

**This is your safety net in case of catastrophic failure during migration!**

---

**Boot from NixOS live USB, mount filesystem, create subvolumes, migrate data.**

#### Step 2.1: Mount Btrfs Root
```bash
# Mount the Btrfs root volume
mount -t btrfs -o subvolid=5 /dev/disk/by-uuid/a895216b-d275-480c-9b78-04c6a00df14a /mnt
cd /mnt
```

#### Step 2.2: Safety Backups
```bash
# Create snapshot backup of current @home (SAFETY)
btrfs subvolume snapshot @home @home-backup

# Create snapshot for Snapper (optional, for immediate rollback via Snapper)
mkdir -p @home/.snapshots
btrfs subvolume snapshot @home "@home/.snapshots/pre-impermanence-$(date +%Y%m%d-%H%M%S)"
```

#### Step 2.3: Create New Persist Subvolumes
```bash
# Create dotfiles persist subvolume
btrfs subvolume create @persist-dotfiles

# Create userfiles persist subvolume
btrfs subvolume create @persist-userfiles

# Set ownership
chown -R 1000:100 @persist-dotfiles  # joemitz:users (UID:GID)
chown -R 1000:100 @persist-userfiles
```

#### Step 2.4: Migrate Dotfiles to @persist-dotfiles
```bash
# Create base directory structure
mkdir -p @persist-dotfiles/joemitz

# Copy dotfiles (preserving attributes)
cd @home/joemitz

# Copy critical configs first
cp -a .ssh @persist-dotfiles/joemitz/
cp -a .git-credentials @persist-dotfiles/joemitz/
cp -a .claude @persist-dotfiles/joemitz/
cp -a .claude.json @persist-dotfiles/joemitz/
cp -a .claude.json.backup @persist-dotfiles/joemitz/ 2>/dev/null || true

# Copy app configs
cp -a .config @persist-dotfiles/joemitz/
cp -a .local @persist-dotfiles/joemitz/
cp -a .android @persist-dotfiles/joemitz/
cp -a .mozilla @persist-dotfiles/joemitz/
cp -a .var @persist-dotfiles/joemitz/
cp -a .vscode-oss @persist-dotfiles/joemitz/
cp -a .zoom @persist-dotfiles/joemitz/

# Copy shell configs
cp -a .bashrc @persist-dotfiles/joemitz/
cp -a .bash_profile @persist-dotfiles/joemitz/
cp -a .profile @persist-dotfiles/joemitz/
cp -a .bash_history @persist-dotfiles/joemitz/
cp -a .bash_history_persistent @persist-dotfiles/joemitz/

# Copy build caches
cp -a .gradle @persist-dotfiles/joemitz/
cp -a .npm @persist-dotfiles/joemitz/
cp -a .cargo @persist-dotfiles/joemitz/
cp -a .compose-cache @persist-dotfiles/joemitz/
cp -a .java @persist-dotfiles/joemitz/
cp -a .react-native-cli @persist-dotfiles/joemitz/
cp -a .crashlytics @persist-dotfiles/joemitz/
cp -a .nix-defexpr @persist-dotfiles/joemitz/
cp -a .nix-profile @persist-dotfiles/joemitz/

# Copy other dotfiles
cp -a .gtkrc-2.0 @persist-dotfiles/joemitz/
cp -a .npmrc @persist-dotfiles/joemitz/
cp -a .pki @persist-dotfiles/joemitz/
cp -a .icons @persist-dotfiles/joemitz/

# Create and migrate selective cache
mkdir -p @persist-dotfiles/joemitz/.cache
cp -a .cache/nix @persist-dotfiles/joemitz/.cache/
cp -a .cache/borg @persist-dotfiles/joemitz/.cache/
cp -a .cache/node-gyp @persist-dotfiles/joemitz/.cache/

# Fix ownership
chown -R 1000:100 @persist-dotfiles/joemitz
```

#### Step 2.5: Migrate Userfiles to @persist-userfiles
```bash
# Create base directory
mkdir -p @persist-userfiles/joemitz

# Copy user directories
cd @home/joemitz
cp -a Android @persist-userfiles/joemitz/
cp -a anova @persist-userfiles/joemitz/
cp -a nixos-config @persist-userfiles/joemitz/
cp -a Desktop @persist-userfiles/joemitz/
cp -a Documents @persist-userfiles/joemitz/
cp -a Downloads @persist-userfiles/joemitz/
cp -a Pictures @persist-userfiles/joemitz/
cp -a Videos @persist-userfiles/joemitz/
cp -a Music @persist-userfiles/joemitz/
cp -a Templates @persist-userfiles/joemitz/
cp -a Public @persist-userfiles/joemitz/
cp -a Postman @persist-userfiles/joemitz/
cp -a Library @persist-userfiles/joemitz/
cp -a misc @persist-userfiles/joemitz/
cp -a ssh-backup @persist-userfiles/joemitz/

# Fix ownership
chown -R 1000:100 @persist-userfiles/joemitz
```

#### Step 2.6: Rename Subvolumes and Cleanup
```bash
cd /mnt

# Rename @root-blank to @blank for clarity
mv @root-blank @blank

# Rename @persist to @persist-root for consistent naming
mv @persist @persist-root

# Delete @home subvolume (we have backups, and it's no longer needed!)
# /home will just be a directory on @ going forward
btrfs subvolume delete @home

# Delete @snapshots subvolume (no longer needed - we only snapshot persist subvolumes)
btrfs subvolume delete @snapshots

# Clean out .snapshots directory from @home-backup if it exists
rm -rf @home-backup/joemitz/.snapshots 2>/dev/null || true

# Delete old-root-backup if it exists (leftover from previous migrations)
btrfs subvolume delete @old-root-backup 2>/dev/null || true
```

#### Step 2.7: Verify Migration
```bash
# Check subvolumes exist
btrfs subvolume list /mnt

# Check data migrated correctly
ls -la /mnt/@persist-dotfiles/joemitz/
ls -la /mnt/@persist-userfiles/joemitz/

# Unmount
cd /
umount /mnt
```

**Reboot back to installed system (DO NOT boot with new config yet)**

---

### Phase 3: Update NixOS Configuration

#### File: `hardware-configuration.nix`

**Change 1: Remove /home mount** (delete lines 22-27):
```nix
# DELETE THIS ENTIRE BLOCK - /home will be a directory on @ now:
fileSystems."/home" =
  { device = "/dev/disk/by-uuid/a895216b-d275-480c-9b78-04c6a00df14a";
    fsType = "btrfs";
    options = [ "subvol=@home" "compress=zstd" "noatime" "space_cache=v2" ];
    neededForBoot = true;
  };
```

**Change 2: Rename /persist to /persist-root** (lines 41-46):
```nix
# CHANGE FROM:
fileSystems."/persist" =
  { device = "/dev/disk/by-uuid/a895216b-d275-480c-9b78-04c6a00df14a";
    fsType = "btrfs";
    options = [ "subvol=@persist" "compress=zstd" "noatime" ];
    neededForBoot = true;
  };

# TO:
fileSystems."/persist-root" =
  { device = "/dev/disk/by-uuid/a895216b-d275-480c-9b78-04c6a00df14a";
    fsType = "btrfs";
    options = [ "subvol=@persist-root" "compress=zstd" "noatime" ];
    neededForBoot = true;
  };
```

**Change 3: Remove /.snapshots mount** (delete lines 48-53):
```nix
# DELETE THIS - @snapshots subvolume no longer exists:
fileSystems."/.snapshots" =
  { device = "/dev/disk/by-uuid/a895216b-d275-480c-9b78-04c6a00df14a";
    fsType = "btrfs";
    options = [ "subvol=@snapshots" "compress=zstd" "noatime" ];
    neededForBoot = true;
  };
```

**Change 4: Add new persist subvolume mounts** (after line 46):
```nix
fileSystems."/persist-dotfiles" =
  { device = "/dev/disk/by-uuid/a895216b-d275-480c-9b78-04c6a00df14a";
    fsType = "btrfs";
    options = [ "subvol=@persist-dotfiles" "compress=zstd" "noatime" ];
    neededForBoot = true;
  };

fileSystems."/persist-userfiles" =
  { device = "/dev/disk/by-uuid/a895216b-d275-480c-9b78-04c6a00df14a";
    fsType = "btrfs";
    options = [ "subvol=@persist-userfiles" "compress=zstd" "noatime" ];
    neededForBoot = true;
  };
```

---

#### File: `configuration.nix`

**Change 1: Update Boot Script** (lines 24-50, modify existing boot.initrd.postDeviceCommands)

```nix
boot.initrd.postDeviceCommands = pkgs.lib.mkAfter ''
  mkdir -p /mnt

  # Mount the btrfs root to /mnt for subvolume manipulation
  mount -t btrfs -o subvolid=5 /dev/disk/by-uuid/a895216b-d275-480c-9b78-04c6a00df14a /mnt

  # === ROOT WIPE (update to use @blank) ===
  # Delete all nested subvolumes recursively before removing root
  while btrfs subvolume list -o /mnt/@ | grep -q .; do
    btrfs subvolume list -o /mnt/@ |
    cut -f9 -d' ' |
    while read subvolume; do
      echo "deleting /$subvolume subvolume..."
      btrfs subvolume delete "/mnt/$subvolume" || true
    done
  done

  echo "deleting /@ subvolume..."
  btrfs subvolume delete /mnt/@

  echo "restoring blank /@ subvolume..."
  btrfs subvolume snapshot /mnt/@blank /mnt/@

  # Create /home directory structure (no separate @home subvolume needed!)
  mkdir -p /mnt/@/home/joemitz
  chown 1000:100 /mnt/@/home/joemitz
  chmod 700 /mnt/@/home/joemitz

  # Unmount and continue boot process
  umount /mnt
'';
```

**Note:** Only @root-blank → @blank rename needed. No separate home wipe - /home is just a directory on @ now!

**Change 2: Rename System Persistence Path** (around line 198):
```nix
# CHANGE FROM:
environment.persistence."/persist" = {
  hideMounts = true;
  directories = [ ... ];
  files = [ ... ];
};

# TO:
environment.persistence."/persist-root" = {
  hideMounts = true;
  directories = [ ... ];  # Keep existing content
  files = [ ... ];  # Keep existing content
};
```

**Change 3: Add Home Impermanence Config** (after line 233, after system persistence)

```nix
# Home impermanence - dotfiles
environment.persistence."/persist-dotfiles" = {
  hideMounts = true;

  users.joemitz = {
    directories = [
      ".ssh"
      ".claude"
      # IMPORTANT: Use narrow paths for .config, not the entire directory!
      # Examples of narrow .config paths (add more as needed):
      ".config/alacritty"
      ".config/kate"
      ".config/git"
      ".config/gh"
      ".config/borg"
      ".config/sops"          # CRITICAL: age keys for sops-nix secrets
      ".config/environment.d"
      # Add other .config subdirs as needed (gtk-3.0, gtk-4.0, etc.)

      # Similar for .local - use narrow paths where possible:
      # Examples of .local subdirectories that can be persisted individually:
      ".local/share/applications"  # Desktop entries
      ".local/share/keyrings"      # Keyrings/passwords
      ".local/share/konsole"       # Konsole profiles
      ".local/share/kwalletd"      # KWallet
      ".local/state/wireplumber"   # Audio state
      # Note: You may need to persist more .local subdirs - start narrow and add as needed

      ".android"
      ".mozilla"
      ".var"
      ".vscode-oss"
      ".zoom"
      ".gradle"
      ".npm"
      ".cargo"
      ".compose-cache"
      ".java"
      ".react-native-cli"
      ".crashlytics"
      ".nix-defexpr"
      ".nix-profile"
      ".pki"
      ".icons"
      { directory = ".cache/nix"; mode = "0755"; }
      { directory = ".cache/borg"; mode = "0755"; }
      { directory = ".cache/node-gyp"; mode = "0755"; }
    ];

    files = [
      ".git-credentials"
      ".claude.json"
      ".claude.json.backup"
      ".bashrc"
      ".bash_profile"
      ".profile"
      ".bash_history"
      ".bash_history_persistent"
      ".gtkrc-2.0"
      ".npmrc"
    ];
  };
};

# NOTE: The above is a starting point. After first boot, many apps will have
# lost their settings. You'll need to iteratively add more .config and .local
# paths as you discover what needs to persist. This is expected with narrow paths.
# Process: app loses config → identify what it needs → add to this list → rebuild.
# Keep paths narrow (e.g., .config/kate, not .config) to make it explicit
# what's being kept and to avoid persisting unnecessary data.

# Home impermanence - userfiles
environment.persistence."/persist-userfiles" = {
  hideMounts = true;

  users.joemitz = {
    directories = [
      "Android"
      "anova"
      "nixos-config"
      "Desktop"
      "Documents"
      "Downloads"
      "Pictures"
      "Videos"
      "Music"
      "Templates"
      "Public"
      "Postman"
      "Library"
      "misc"
      "ssh-backup"
    ];
  };
};
```

**Change 5: Update Snapper Configs** (around line 323-360)

**Remove "root" and "home" configs** (wiped on boot, snapshots are useless):
```nix
# DELETE these configs:
root = {
  SUBVOLUME = "/";
  ...
};

home = {
  SUBVOLUME = "/home";
  ...
};
```

**Rename "persist" to "persist-root":**
```nix
# CHANGE FROM:
persist = {
  SUBVOLUME = "/persist";
  ...
};

# TO:
persist-root = {
  SUBVOLUME = "/persist-root";
  ALLOW_USERS = [ "joemitz" ];
  TIMELINE_CREATE = true;
  TIMELINE_CLEANUP = true;
  TIMELINE_LIMIT_HOURLY = "48";
  TIMELINE_LIMIT_DAILY = "7";
  TIMELINE_LIMIT_WEEKLY = "4";
  TIMELINE_LIMIT_MONTHLY = "12";
  TIMELINE_LIMIT_YEARLY = "2";
};
```

**Add new persist configs:**
```nix
services.snapper = {
  configs = {
    # Only snapshot persist subvolumes (actual persistent data)
    # Removed: root, home (wiped on boot)

    persist-root = { /* ... */ };  # Renamed from persist

    persist-dotfiles = {
      SUBVOLUME = "/persist-dotfiles";
      ALLOW_USERS = [ "joemitz" ];
      TIMELINE_CREATE = true;
      TIMELINE_CLEANUP = true;
      TIMELINE_LIMIT_HOURLY = "48";
      TIMELINE_LIMIT_DAILY = "7";
      TIMELINE_LIMIT_WEEKLY = "4";
      TIMELINE_LIMIT_MONTHLY = "12";
      TIMELINE_LIMIT_YEARLY = "2";
    };

    persist-userfiles = {
      SUBVOLUME = "/persist-userfiles";
      ALLOW_USERS = [ "joemitz" ];
      TIMELINE_CREATE = true;
      TIMELINE_CLEANUP = true;
      TIMELINE_LIMIT_HOURLY = "48";
      TIMELINE_LIMIT_DAILY = "7";
      TIMELINE_LIMIT_WEEKLY = "4";
      TIMELINE_LIMIT_MONTHLY = "12";
      TIMELINE_LIMIT_YEARLY = "2";
    };
  };
};
```

**Change 5: Update Borg Backup** (optional, around line 290)

Update backup paths to use new naming:

```nix
# CHANGE FROM:
paths = [
  "/persist"
];

# TO:
paths = [
  "/persist-root"          # Renamed
  "/persist-dotfiles"      # Add
  "/persist-userfiles"     # Add
];
```

---

### Phase 4: Test & Verify

#### Step 4.1: Test Configuration
```bash
# Test config is valid
nixos-rebuild test --flake /home/joemitz/nixos-config

# If successful, build boot configuration (doesn't activate yet)
nixos-rebuild boot --flake /home/joemitz/nixos-config
```

#### Step 4.2: First Reboot
```bash
# Reboot to test home impermanence
reboot
```

**After reboot, verify:**

1. **Check mounts:**
```bash
mount | grep persist
# Should see: /persist-dotfiles and /persist-userfiles with neededForBoot
```

2. **Check bind mounts:**
```bash
findmnt -t btrfs | grep home
# Should see bind mounts from /persist-dotfiles and /persist-userfiles to /home/joemitz
```

3. **Verify data access:**
```bash
ls -la ~/.ssh        # Should see SSH keys
ls -la ~/.config     # Should see configs
ls ~/nixos-config    # Should see project files
claude --version     # Claude should work with persisted config
```

4. **Check Snapper:**
```bash
# List all configs - should only show 3 persist configs
snapper list-configs
# Expected: persist-root, persist-dotfiles, persist-userfiles
# NOT: root, home

# Check snapshots are being created
sudo snapper -c persist-root list
sudo snapper -c persist-dotfiles list
sudo snapper -c persist-userfiles list
```

5. **Test application access:**
- Open Firefox (profile should be intact)
- Open Kate (settings should be intact)
- Run `git config --global user.name` (should be preserved)

#### Step 4.3: Verify Wipe Behavior
```bash
# Create test file in home
touch ~/test-ephemeral.txt

# Reboot
reboot

# After reboot, test file should be GONE
ls ~/test-ephemeral.txt  # Should not exist

# But persisted files should remain
ls ~/.ssh  # Should still exist
```

---

### Phase 5: Cleanup (After Successful Testing)

Once everything works correctly:

```bash
# Boot from live USB again
mount -t btrfs -o subvolid=5 /dev/disk/by-uuid/a895216b-d275-480c-9b78-04c6a00df14a /mnt

# Delete backup subvolume (keep @home-backup for a while as safety)
# btrfs subvolume delete /mnt/@home-backup  # Keep this for now

umount /mnt
```

---

## Critical Files to Modify

1. **hardware-configuration.nix**
   - Lines 22-27: **DELETE** `/home` mount (no longer needed!)
   - Lines 41-46: **RENAME** `/persist` → `/persist-root` (subvol=@persist-root)
   - Lines 48-53: **DELETE** `/.snapshots` mount (subvolume removed)
   - After line 46: **ADD** `/persist-dotfiles` and `/persist-userfiles` mounts with `neededForBoot = true`

2. **configuration.nix** (multiple locations)
   - Lines 24-50: **UPDATE** `boot.initrd.postDeviceCommands`:
     - Change `@root-blank` to `@blank`
     - Add `/home/joemitz` directory creation after @ snapshot
   - Around line 198: **RENAME** `environment.persistence."/persist"` → `environment.persistence."/persist-root"`
   - After line 233: **ADD** two new `environment.persistence` blocks (dotfiles + userfiles)
   - Lines 323-360: **UPDATE** Snapper configs:
     - **Remove "root" and "home" configs** (wiped on boot - snapshots useless)
     - Rename "persist" → "persist-root"
     - Add "persist-dotfiles" and "persist-userfiles" configs
   - Around line 290 (optional): **UPDATE** Borg backup paths (rename + add new paths)

---

## Boot Sequence with Home Impermanence

```
1. Kernel boots, discovers devices
2. initramfs runs boot.initrd.postDeviceCommands:
   a. Wipes @ (root) → recreates from @blank
   b. Creates /home/joemitz directory structure on fresh @ ← NEW (simplified!)
3. initramfs mounts filesystems with neededForBoot:
   - / (fresh @, contains /home directory)
   - /nix (@nix - persistent)
   - /persist-root (@persist-root - persistent, renamed from @persist)
   - /persist-dotfiles (@persist-dotfiles - persistent) ← NEW
   - /persist-userfiles (@persist-userfiles - persistent) ← NEW
4. Root filesystem transitions from initramfs to real root
5. Activation scripts run:
   - impermanence module creates bind mounts:
     * /persist-root → @ (system state)
     * /persist-dotfiles/joemitz → /home/joemitz (dotfiles) ← NEW
     * /persist-userfiles/joemitz → /home/joemitz (userfiles) ← NEW
6. sops-nix decrypts secrets to /home/joemitz/.config/secrets.env
   - This works because .config is bind-mounted from /persist-dotfiles
7. Services start, user can login
```

**Note:** Much simpler - no separate @home subvolume or mount point needed!

---

## sops-nix Compatibility

**Important:** sops-nix will continue to work because:
- `/home/joemitz/.config/secrets.env` is where secrets are written
- `.config/sops` will be bind-mounted from `/persist-dotfiles/joemitz/.config/sops`
- Age keys at `~/.config/sops/age/keys.txt` will persist
- **CRITICAL**: You MUST include `.config/sops` in the persist-dotfiles directories list (see Change 3 above)
- No other changes needed to sops configuration!

---

## Rollback Plan

If home impermanence causes issues, you can roll back to the previous setup:

### Step 1: Boot from Live USB
Boot from a NixOS live USB to access the filesystem.

### Step 2: Mount Filesystem
```bash
mount -t btrfs -o subvolid=5 /dev/disk/by-uuid/a895216b-d275-480c-9b78-04c6a00df14a /mnt
cd /mnt
```

### Step 3: Restore Subvolumes
```bash
# Restore @home subvolume from backup
btrfs subvolume snapshot @home-backup @home

# Restore @persist from @persist-root
mv @persist-root @persist

# Restore @root-blank from @blank
mv @blank @root-blank

# Recreate @snapshots subvolume if needed
btrfs subvolume create @snapshots
```

### Step 4: Delete New Subvolumes (Optional)
```bash
# Delete the new persist subvolumes (optional - can keep them for future attempt)
# btrfs subvolume delete @persist-dotfiles
# btrfs subvolume delete @persist-userfiles
```

### Step 5: Reboot to Installed System
```bash
cd /
umount /mnt
reboot
```
Boot back into your installed NixOS system (it will use the old configuration).

### Step 6: Revert Configuration Changes
Once booted, revert the configuration changes:

**In hardware-configuration.nix:**
- Restore /home mount (pointing to @home subvolume)
- Rename /persist-root back to /persist (subvol=@persist)
- Restore /.snapshots mount
- Remove /persist-dotfiles and /persist-userfiles mounts

**In configuration.nix:**
- Revert boot.initrd.postDeviceCommands to use @root-blank (remove @blank and /home/joemitz creation)
- Rename environment.persistence."/persist-root" back to "/persist"
- Remove the two new environment.persistence blocks (dotfiles and userfiles)
- Restore Snapper configs for "root" and "home"
- Rename Snapper "persist-root" back to "persist"
- Remove "persist-dotfiles" and "persist-userfiles" Snapper configs
- Revert Borg backup paths if changed

### Step 7: Rebuild System
```bash
nhs  # or nixos-rebuild switch
```

### Step 8: Verify Rollback
After rebuilding and rebooting:
- Check that /home is mounted from @home subvolume
- Verify all your data is accessible
- Confirm applications work correctly

---

## Estimated Disk Usage

- **@persist-dotfiles:** ~8-9 GB (configs + selective caches)
- **@persist-userfiles:** Varies (projects, documents, media)
- **@blank:** <1 MB (empty, shared by both @ and @home)
- **@home-backup:** Same as current /home (keep temporarily for safety)

---

## Testing Checklist

- [ ] Created home-impermanence branch
- [ ] @persist-dotfiles and @persist-userfiles subvolumes created
- [ ] Data migrated to persist subvolumes
- [ ] @home subvolume deleted (no longer needed!)
- [ ] @snapshots subvolume deleted (no longer needed!)
- [ ] @old-root-backup deleted (if it exists)
- [ ] .snapshots cleaned from @home-backup
- [ ] @root-blank renamed to @blank
- [ ] @persist renamed to @persist-root
- [ ] /home mount removed from hardware-configuration.nix
- [ ] /.snapshots mount removed from hardware-configuration.nix
- [ ] /persist mount renamed to /persist-root in hardware-configuration.nix
- [ ] environment.persistence."/persist" renamed to "/persist-root"
- [ ] "root" Snapper config removed (snapshots useless for wiped subvolumes)
- [ ] "home" Snapper config removed
- [ ] "persist" Snapper config renamed to "persist-root"
- [ ] Boot script updated (@blank + /home/joemitz creation)
- [ ] Impermanence configs added for both new persist subvolumes
- [ ] Snapper configs added for 3 persist subvolumes only
- [ ] `nixos-rebuild boot` succeeds
- [ ] First reboot successful
- [ ] /home is a directory on @ (not separate mount)
- [ ] All bind mounts present (`findmnt` check)
- [ ] SSH keys accessible (~/.ssh)
- [ ] Git credentials work
- [ ] Claude Code config intact
- [ ] Firefox profile accessible
- [ ] Kate settings preserved
- [ ] Projects (anova, nixos-config) accessible
- [ ] Ephemeral test file disappears after reboot
- [ ] Snapper creating snapshots for all 3 persist subvolumes (persist-root, persist-dotfiles, persist-userfiles)
- [ ] NO Snapper snapshots for / or /home (confirmed with `snapper list-configs`)
- [ ] Borg backup working (if enabled)
- [ ] sops-nix secrets still decrypt correctly

---

## Optional: Maintenance Script to Find Orphaned Files

After implementation, you may want to periodically check for files in persist subvolumes that aren't declared in your configuration. Create this script:

**File: `~/bin/check-orphaned-persist.sh`**

```bash
#!/usr/bin/env bash
# Find files in persist subvolumes not declared in configuration.nix

echo "=== Orphaned Files in Persist Subvolumes ==="
echo ""
echo "These files/folders exist in persist but are NOT in your configuration.nix"
echo "Decide: Should they be added to config? Or deleted?"
echo ""

# Simple approach: list top-level items and let you compare manually
echo "=== persist-dotfiles contents ==="
ls -lh /persist-dotfiles/joemitz/ 2>/dev/null | tail -n +2
echo ""

echo "=== persist-userfiles contents ==="
ls -lh /persist-userfiles/joemitz/ 2>/dev/null | tail -n +2
echo ""

echo "=== persist-root contents ==="
ls -lh /persist-root/ 2>/dev/null | tail -n +2
echo ""

# Show sizes
echo "=== Disk usage by top-level directory ==="
echo ""
echo "Dotfiles:"
du -sh /persist-dotfiles/joemitz/* /persist-dotfiles/joemitz/.* 2>/dev/null | sort -hr | head -20
echo ""
echo "Userfiles:"
du -sh /persist-userfiles/joemitz/* 2>/dev/null | sort -hr | head -20
echo ""

echo "Compare the above with your configuration.nix environment.persistence blocks"
echo "To delete orphaned data: sudo rm -rf /persist-dotfiles/joemitz/.unwanted"
```

**Usage:**
```bash
chmod +x ~/bin/check-orphaned-persist.sh
~/bin/check-orphaned-persist.sh
```

**Run this periodically** (monthly?) to:
1. Identify files not in your config
2. Decide if they should be added or deleted
3. Keep your persist subvolumes clean

**Remember:** Removing a path from `environment.persistence` does NOT delete the files from the persist subvolume - they remain there. This script helps you find and clean up those orphans.

---

## Notes & Warnings

⚠️ **CRITICAL:**
- **CREATE FULL DISK IMAGE WITH CLONEZILLA BEFORE STARTING!** This is your ultimate safety net.
- Back up important data separately (especially Age key at `~/.config/sops/age/keys.txt`)
- Keep `@home-backup` subvolume for at least a week after successful migration
- Keep the Clonezilla disk image until you've verified everything works perfectly
- Test thoroughly before deleting any backups

⚠️ **Expect Iterative Configuration:**
- **After the first boot, many applications will lose their settings** because their `.config` subdirectories aren't in the persistence list yet
- This is intentional and expected with the narrow path strategy
- You will need to iteratively add more paths as you discover what needs to persist
- Process: Notice app lost config → check what it needs in `.config` or `.local` → add specific path to configuration → rebuild
- Keep a text file handy to track paths you need to add
- Don't panic - your data is safe in the persist subvolumes, you just need to tell the system to bind-mount it
- The maintenance script (see below) can help identify what's in persist but not mounted

⚠️ **Boot Order is Critical:**
- Persist subvolumes MUST have `neededForBoot = true`
- Home wipe happens in initrd, before normal mounts
- Impermanence bind mounts happen during activation, after filesystems are mounted

⚠️ **Narrow Persistence:**
- Keep paths narrow and specific (e.g., `.config/kate`, NOT `.config`)
- This makes it explicit what's being persisted and avoids unnecessary data
- Any unlisted paths will NOT persist across reboots
- Start narrow, add more paths as you discover what needs to persist
- When in doubt, use specific subdirectories rather than entire directories

⚠️ **Cache Strategy:**
- Large caches (.gradle 3.7G, .npm 226M) are persisted for build performance
- Browser/UI caches are NOT persisted (auto-regenerate quickly)
- Adjust based on your preferences after testing

---

## Key Simplifications vs. Original Plan

Through iterative refinement, we achieved a much simpler design:

1. **Single @blank instead of @root-blank + @home-blank**
   - @root-blank renamed to @blank
   - Both @ and @home (when it existed) use the same empty snapshot
   - Saves disk space and conceptual complexity

2. **No separate @home subvolume** ← MAJOR SIMPLIFICATION
   - /home is just a directory on @, wiped along with the rest of root
   - Eliminates one subvolume, one mount point, one Snapper config
   - Simpler boot script (only wipe @, not @ and @home)
   - All user data persists via @persist-dotfiles and @persist-userfiles anyway!

**Final architecture:**
- @ (wiped on boot, contains /home directory)
- @persist-root (persistent system state, renamed from @persist)
- @persist-dotfiles (persistent user configs)
- @persist-userfiles (persistent user files)

Much cleaner than the traditional @home approach, with consistent naming across all persist subvolumes!
