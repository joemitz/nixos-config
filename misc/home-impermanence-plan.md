# Home Impermanence Implementation Plan (REVISED)

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
├── @blank                 Empty reference snapshot (COPIED from @root-blank)   ← NEW
├── @root-blank            Empty reference (kept until Phase 5)
├── @home                  REMOVED in Phase 5 (no longer needed)
├── @home-backup           Safety backup of current @home                       ← NEW (temporary)
├── @nix                   (/nix) - Persistent
├── @persist               System state (kept until Phase 5)
├── @persist-root          (/persist-root) - Persistent (COPIED from @persist) ← NEW
├── @persist-dotfiles      (/persist-dotfiles) - Persistent (user dotfiles)    ← NEW
├── @persist-userfiles     (/persist-userfiles) - Persistent (user files)      ← NEW
└── @snapshots             REMOVED in Phase 5
```

**Key Design Decisions:**
1. **Snapshot approach:** Create `@blank` and `@persist-root` as snapshots of originals, both coexist during testing
2. **Old generations work:** Previous generations can still boot because `@root-blank` and `@persist` exist
3. **No separate @home subvolume:** /home is just a directory on @ that gets wiped
4. **Broad KDE persistence:** Persist entire `.config`, `.local/share`, `.local/state` for KDE Plasma compatibility
5. **Remove @snapshots:** Only snapshot the persist subvolumes (data that actually persists)
6. **Disable Snapper for root/home:** They're wiped on boot, snapshots are useless

## Persistence Strategy

### Dotfiles → @persist-dotfiles (mounted at /persist-dotfiles)
Bind mounted to `/home/joemitz/.<name>`.

**Strategy: Broad KDE-compatible persistence**

Directories:
- `.ssh` - SSH keys, known_hosts (CRITICAL for remote access)
- `.claude` - Claude Code data
- `.config` - **ENTIRE directory** (includes all KDE Plasma configs, app settings)
- `.local/share` - **ENTIRE directory** (KDE data, application data, keyrings)
- `.local/state` - **ENTIRE directory** (application state, wireplumber)
- `.android` - Android Studio settings + AVDs
- `.mozilla` - Firefox profiles
- `.var` - Flatpak app data
- `.vscode-oss` - VSCodium settings
- `.zoom` - Zoom settings
- `.gradle` - Gradle build cache (large but speeds up builds)
- `.npm` - NPM package cache
- `.cargo` - Rust toolchain cache
- `.compose-cache` - Docker compose cache
- `.java` - Java settings/cache
- `.react-native-cli` - React Native CLI data
- `.crashlytics` - Crashlytics cache
- `.nix-defexpr`, `.nix-profile` - Nix user environment
- `.pki` - Certificate store
- `.icons` - Icon themes
- `.cache/nix` - Nix cache (expensive to rebuild)
- `.cache/borg` - Borg backup cache
- `.cache/node-gyp` - Native module build cache

Files:
- `.git-credentials` - Git credential store
- `.claude.json`, `.claude.json.backup` - Claude config
- `.bashrc`, `.bash_profile`, `.profile` - Shell configs
- `.bash_history`, `.bash_history_persistent` - Command history
- `.gtkrc-2.0`, `.gtkrc` - GTK config
- `.npmrc` - NPM config

**Note:** Using broad `.config` and `.local` persistence ensures all KDE Plasma settings persist (panels, widgets, shortcuts, window rules, themes, etc.).

### Userfiles → @persist-userfiles (mounted at /persist-userfiles)
Non-dotfile directories. Bind mounted to `/home/joemitz/<name>`.

- `Android/` - Android SDK
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

### What Gets Wiped
Anything in `/home/joemitz/` not covered by the persistence lists above will be wiped on every boot. This is intentional - only explicitly declared state persists.

## Implementation Phases

### Phase 1: Preparation (Current System)

⚠️ **CRITICAL: BACKUP YOUR ENTIRE DISK FIRST!** ⚠️

Before proceeding, create a full disk image with Clonezilla:
1. Boot Clonezilla Live USB
2. Choose "device-image" mode
3. Save entire disk image to external drive
4. Verify the backup completed successfully
5. Keep this backup until you've verified the new setup works perfectly

**This is your safety net in case of catastrophic failure during migration!**

#### Step 1.1: Create Branch
```bash
cd ~/nixos-config
git checkout -b home-impermanence
git push -u origin home-impermanence
```

This keeps the experimental work isolated from your main branch.

---

### Phase 2: Update NixOS Configuration (Current System - DON'T REBOOT)

**Update configuration files and build new boot config. DO NOT REBOOT until Phase 3 is complete!**

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
# DELETE THIS - @snapshots subvolume will be removed:
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

  # === ROOT WIPE (use @blank) ===
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

**Note:** Uses `@blank` which will be created in Phase 3 as a snapshot of `@root-blank`.

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
# Home impermanence - dotfiles (BROAD KDE-compatible persistence)
environment.persistence."/persist-dotfiles" = {
  hideMounts = true;

  users.joemitz = {
    directories = [
      ".ssh"
      ".claude"
      ".config"              # ENTIRE directory (all KDE configs)
      ".local/share"         # ENTIRE directory (KDE data, keyrings)
      ".local/state"         # ENTIRE directory (app state)
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
      ".gtkrc"
      ".npmrc"
    ];
  };
};

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

**Change 4: Update Snapper Configs** (around line 323-360)

**Remove "root" and "home" configs** (wiped on boot, snapshots are useless):
```nix
# DELETE these configs entirely:
root = {
  SUBVOLUME = "/";
  ...
};

home = {
  SUBVOLUME = "/home";
  ...
};
```

**Rename "persist" to "persist-root" and add new persist configs:**
```nix
services.snapper = {
  configs = {
    # Only snapshot persist subvolumes (actual persistent data)
    # Removed: root, home (wiped on boot)

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

**Change 5: Update Borg Backup** (optional, around line 377):

Update backup paths to include all persist subvolumes:

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

#### Step 2.1: Build New Boot Configuration

**Build the new boot configuration WITHOUT activating it yet:**
```bash
# This builds the new config and makes it available at next boot,
# but doesn't activate it now (system still uses current config)
nh os boot /home/joemitz/nixos-config

# Or if nh isn't working:
nixos-rebuild boot --flake /home/joemitz/nixos-config
```

**⚠️ DO NOT REBOOT YET!** The new boot configuration is ready but the subvolumes don't exist yet. Proceed to Phase 3.

---

### Phase 3: Live USB - Create Subvolumes, Migrate Data, Reboot

**Boot from NixOS live USB, create subvolumes as snapshots, migrate data, then reboot to activate new config.**

#### Step 3.1: Mount Btrfs Root
```bash
# Mount the Btrfs root volume
mount -t btrfs -o subvolid=5 /dev/disk/by-uuid/a895216b-d275-480c-9b78-04c6a00df14a /mnt
cd /mnt
```

#### Step 3.2: Create New Subvolumes as Snapshots

```bash
# Create @blank as snapshot of @root-blank
# Both will coexist - old generations use @root-blank, new uses @blank
btrfs subvolume snapshot /mnt/@root-blank /mnt/@blank
echo "@blank created from @root-blank"

# Create @persist-root as snapshot of @persist
# Both will coexist - old generations use @persist, new uses @persist-root
btrfs subvolume snapshot /mnt/@persist /mnt/@persist-root
echo "@persist-root created from @persist"

# Create safety backup of current @home
btrfs subvolume snapshot /mnt/@home /mnt/@home-backup
echo "@home-backup created"

# Create new persist subvolumes for user data
btrfs subvolume create /mnt/@persist-dotfiles
btrfs subvolume create /mnt/@persist-userfiles
echo "Created @persist-dotfiles and @persist-userfiles"

# Create base directory structure with proper ownership
mkdir -p /mnt/@persist-dotfiles/joemitz
mkdir -p /mnt/@persist-userfiles/joemitz
chown -R 1000:100 /mnt/@persist-dotfiles/joemitz  # joemitz:users (UID:GID)
chown -R 1000:100 /mnt/@persist-userfiles/joemitz
echo "Directory structure created"
```

#### Step 3.3: Migrate Dotfiles to @persist-dotfiles
```bash
# Navigate to source directory
cd /mnt/@home/joemitz

# Copy critical configs first (fail if critical ones don't exist)
echo "Copying critical configs..."
cp -a .ssh /mnt/@persist-dotfiles/joemitz/ || { echo "ERROR: .ssh not found!"; exit 1; }
cp -a .git-credentials /mnt/@persist-dotfiles/joemitz/ 2>/dev/null || echo "Warning: .git-credentials not found"
cp -a .claude /mnt/@persist-dotfiles/joemitz/ 2>/dev/null || echo "Warning: .claude not found"
cp -a .claude.json /mnt/@persist-dotfiles/joemitz/ 2>/dev/null || echo "Warning: .claude.json not found"
cp -a .claude.json.backup /mnt/@persist-dotfiles/joemitz/ 2>/dev/null || true

# Copy entire directories (broad approach for KDE compatibility)
echo "Copying application configs and data..."
cp -a .config /mnt/@persist-dotfiles/joemitz/ 2>/dev/null || echo "Warning: .config not found"
cp -a .local /mnt/@persist-dotfiles/joemitz/ 2>/dev/null || echo "Warning: .local not found"
cp -a .android /mnt/@persist-dotfiles/joemitz/ 2>/dev/null || echo "Warning: .android not found"
cp -a .mozilla /mnt/@persist-dotfiles/joemitz/ 2>/dev/null || echo "Warning: .mozilla not found"
cp -a .var /mnt/@persist-dotfiles/joemitz/ 2>/dev/null || echo "Warning: .var not found"
cp -a .vscode-oss /mnt/@persist-dotfiles/joemitz/ 2>/dev/null || echo "Warning: .vscode-oss not found"
cp -a .zoom /mnt/@persist-dotfiles/joemitz/ 2>/dev/null || echo "Warning: .zoom not found"

# Copy shell configs
echo "Copying shell configs..."
cp -a .bashrc /mnt/@persist-dotfiles/joemitz/ 2>/dev/null || echo "Warning: .bashrc not found"
cp -a .bash_profile /mnt/@persist-dotfiles/joemitz/ 2>/dev/null || true
cp -a .profile /mnt/@persist-dotfiles/joemitz/ 2>/dev/null || true
cp -a .bash_history /mnt/@persist-dotfiles/joemitz/ 2>/dev/null || true
cp -a .bash_history_persistent /mnt/@persist-dotfiles/joemitz/ 2>/dev/null || true

# Copy build caches
echo "Copying build caches..."
cp -a .gradle /mnt/@persist-dotfiles/joemitz/ 2>/dev/null || echo "Warning: .gradle not found"
cp -a .npm /mnt/@persist-dotfiles/joemitz/ 2>/dev/null || echo "Warning: .npm not found"
cp -a .cargo /mnt/@persist-dotfiles/joemitz/ 2>/dev/null || echo "Warning: .cargo not found"
cp -a .compose-cache /mnt/@persist-dotfiles/joemitz/ 2>/dev/null || true
cp -a .java /mnt/@persist-dotfiles/joemitz/ 2>/dev/null || true
cp -a .react-native-cli /mnt/@persist-dotfiles/joemitz/ 2>/dev/null || true
cp -a .crashlytics /mnt/@persist-dotfiles/joemitz/ 2>/dev/null || true
cp -a .nix-defexpr /mnt/@persist-dotfiles/joemitz/ 2>/dev/null || true
cp -a .nix-profile /mnt/@persist-dotfiles/joemitz/ 2>/dev/null || true

# Copy other dotfiles
echo "Copying other dotfiles..."
cp -a .gtkrc-2.0 /mnt/@persist-dotfiles/joemitz/ 2>/dev/null || true
cp -a .gtkrc /mnt/@persist-dotfiles/joemitz/ 2>/dev/null || true
cp -a .npmrc /mnt/@persist-dotfiles/joemitz/ 2>/dev/null || true
cp -a .pki /mnt/@persist-dotfiles/joemitz/ 2>/dev/null || true
cp -a .icons /mnt/@persist-dotfiles/joemitz/ 2>/dev/null || true

# Create and migrate selective cache
echo "Copying selective cache directories..."
mkdir -p /mnt/@persist-dotfiles/joemitz/.cache
cp -a .cache/nix /mnt/@persist-dotfiles/joemitz/.cache/ 2>/dev/null || echo "Warning: .cache/nix not found"
cp -a .cache/borg /mnt/@persist-dotfiles/joemitz/.cache/ 2>/dev/null || echo "Warning: .cache/borg not found"
cp -a .cache/node-gyp /mnt/@persist-dotfiles/joemitz/.cache/ 2>/dev/null || true

# Fix ownership
echo "Fixing ownership..."
chown -R 1000:100 /mnt/@persist-dotfiles/joemitz

echo "Dotfiles migration complete!"
```

#### Step 3.4: Migrate Userfiles to @persist-userfiles
```bash
# Navigate to source directory
cd /mnt/@home/joemitz

# Copy user directories (with error handling)
echo "Copying user directories..."
cp -a Android /mnt/@persist-userfiles/joemitz/ 2>/dev/null || echo "Warning: Android not found"
cp -a anova /mnt/@persist-userfiles/joemitz/ 2>/dev/null || echo "Warning: anova not found"
cp -a nixos-config /mnt/@persist-userfiles/joemitz/ || { echo "ERROR: nixos-config not found!"; exit 1; }
cp -a Desktop /mnt/@persist-userfiles/joemitz/ 2>/dev/null || echo "Warning: Desktop not found"
cp -a Documents /mnt/@persist-userfiles/joemitz/ 2>/dev/null || echo "Warning: Documents not found"
cp -a Downloads /mnt/@persist-userfiles/joemitz/ 2>/dev/null || echo "Warning: Downloads not found"
cp -a Pictures /mnt/@persist-userfiles/joemitz/ 2>/dev/null || echo "Warning: Pictures not found"
cp -a Videos /mnt/@persist-userfiles/joemitz/ 2>/dev/null || echo "Warning: Videos not found"
cp -a Music /mnt/@persist-userfiles/joemitz/ 2>/dev/null || echo "Warning: Music not found"
cp -a Templates /mnt/@persist-userfiles/joemitz/ 2>/dev/null || true
cp -a Public /mnt/@persist-userfiles/joemitz/ 2>/dev/null || true
cp -a Postman /mnt/@persist-userfiles/joemitz/ 2>/dev/null || echo "Warning: Postman not found"
cp -a Library /mnt/@persist-userfiles/joemitz/ 2>/dev/null || true
cp -a misc /mnt/@persist-userfiles/joemitz/ 2>/dev/null || true
cp -a ssh-backup /mnt/@persist-userfiles/joemitz/ 2>/dev/null || true

# Fix ownership
echo "Fixing ownership..."
chown -R 1000:100 /mnt/@persist-userfiles/joemitz

echo "Userfiles migration complete!"
```

#### Step 3.5: Verify Migration (CRITICAL!)
```bash
cd /mnt

echo "=== Verifying critical data migration ==="

# Verify critical dotfiles exist
echo "Checking critical dotfiles..."
ls -la /mnt/@persist-dotfiles/joemitz/.ssh/id_* || { echo "ERROR: SSH keys missing!"; exit 1; }
ls -la /mnt/@persist-dotfiles/joemitz/.config/sops/age/keys.txt || { echo "ERROR: Age key missing! sops-nix will break!"; exit 1; }

# Verify critical userfiles exist
echo "Checking critical userfiles..."
ls -d /mnt/@persist-userfiles/joemitz/nixos-config/ || { echo "ERROR: nixos-config missing!"; exit 1; }

# Verify new subvolumes created
echo "Checking new subvolumes..."
btrfs subvolume list /mnt | grep -E "@blank|@persist-root|@persist-dotfiles|@persist-userfiles" || { echo "ERROR: New subvolumes missing!"; exit 1; }

# Show summary
echo ""
echo "=== Migration Summary ==="
echo "Dotfiles subvolume size:"
du -sh /mnt/@persist-dotfiles/joemitz/
echo ""
echo "Userfiles subvolume size:"
du -sh /mnt/@persist-userfiles/joemitz/
echo ""
echo "Backup subvolume size:"
du -sh /mnt/@home-backup/
echo ""

# Check all subvolumes
echo "=== Current Subvolumes ==="
btrfs subvolume list /mnt

echo ""
echo "=== Verification complete! ==="
echo "✓ Critical files verified"
echo "✓ New subvolumes created"
echo "✓ Old subvolumes preserved (@root-blank, @persist, @home still exist)"
echo ""
echo "If all checks passed, you can proceed to reboot."
echo "Otherwise, investigate errors before continuing!"
```

#### Step 3.6: Unmount and Reboot
```bash
# Unmount
cd /
umount /mnt

# Reboot to activate new configuration
echo "Rebooting to activate new configuration..."
reboot
```

**The new boot configuration (built in Phase 2) will activate on this reboot.**

---

### Phase 4: Verify New Configuration

**After rebooting from Phase 3, verify everything works.**

#### Step 4.1: Check Filesystem Mounts
```bash
# Check persist mounts are active
mount | grep persist
# Should see: /persist-root, /persist-dotfiles, /persist-userfiles

# Verify /home is NOT a separate mount (it's just a directory on @)
mount | grep " /home "
# Should see NOTHING - /home is not mounted separately
```

#### Step 4.2: Check Bind Mounts
```bash
# Check bind mounts from persist subvolumes to /home
findmnt -t btrfs | grep home
# Should see bind mounts from /persist-dotfiles and /persist-userfiles to /home/joemitz

# Alternative: check with ls
ls -la ~ | head -20
# Your dotfiles and directories should be visible
```

#### Step 4.3: Verify Critical Data Access
```bash
# Test SSH keys (CRITICAL!)
ls -la ~/.ssh/id_*
# Should see your SSH keys

# Test Age key for sops-nix (CRITICAL!)
ls -la ~/.config/sops/age/keys.txt
# Should exist - if not, sops-nix will break!

# Test project access
cd ~/nixos-config && git status
# Should work normally

# Test Claude Code
claude --version
# Should work with persisted config
```

#### Step 4.4: Test KDE Plasma Settings
- Open KDE System Settings - all settings should be intact
- Check panel configuration - widgets should be present
- Test keyboard shortcuts - custom shortcuts should work
- Open Kate - settings should be preserved
- Open Firefox - profile should be intact
- Run `git config --global user.name` - should be your name

#### Step 4.5: Check Snapper Configs
```bash
# List all configs - should only show 3 persist configs
snapper list-configs
# Expected: persist-root, persist-dotfiles, persist-userfiles
# NOT PRESENT: root, home (removed because they're wiped on boot)

# Check snapshots are being created
sudo snapper -c persist-root list
sudo snapper -c persist-dotfiles list
sudo snapper -c persist-userfiles list
# Should see timeline snapshots
```

#### Step 4.6: Verify Wipe Behavior
```bash
# Create test file in home (should NOT persist across reboots)
touch ~/test-ephemeral.txt
echo "This file should disappear after reboot" > ~/test-ephemeral.txt

# Check it exists now
cat ~/test-ephemeral.txt

# Reboot to test wipe
sudo reboot
```

**After rebooting, verify wipe worked:**
```bash
# Test file should be GONE
ls ~/test-ephemeral.txt
# Should show: No such file or directory

# But persisted files should remain
ls ~/.ssh  # Should still exist
ls ~/nixos-config  # Should still exist
ls ~/.config/plasma*  # KDE configs should still exist
```

**If everything above checks out, use the system for several days before proceeding to Phase 5.**

---

### Phase 5: Cleanup (After Days of Successful Testing)

**ONLY proceed after you've verified everything works perfectly for several days.**

This phase deletes old subvolumes that are no longer needed.

#### Step 5.1: Boot Live USB
Boot from a NixOS live USB to safely manipulate subvolumes.

#### Step 5.2: Mount Filesystem
```bash
# Mount the Btrfs root volume
mount -t btrfs -o subvolid=5 /dev/disk/by-uuid/a895216b-d275-480c-9b78-04c6a00df14a /mnt
cd /mnt
```

#### Step 5.3: Verify Current State
```bash
# List current subvolumes
btrfs subvolume list /mnt

# You should see BOTH old and new subvolumes:
# - @root-blank (old, to be deleted)
# - @blank (new, in use)
# - @persist (old, to be deleted)
# - @persist-root (new, in use)
# - @home (old, to be deleted)
# - @home-backup (keep for now)
# - @snapshots (old, to be deleted)
# - @persist-dotfiles (new, in use)
# - @persist-userfiles (new, in use)
```

#### Step 5.4: Delete Old Subvolumes

```bash
# Delete nested snapshots inside @home first (CRITICAL!)
echo "Deleting nested snapshots in @home..."
btrfs subvolume list /mnt/@home | grep "\.snapshots" | awk '{print $9}' | while read snap; do
  echo "Deleting /mnt/$snap"
  btrfs subvolume delete "/mnt/$snap" 2>/dev/null || true
done

# Delete the .snapshots subvolume itself
btrfs subvolume delete /mnt/@home/.snapshots 2>/dev/null || true

# Now safe to delete @home
btrfs subvolume delete /mnt/@home
echo "@home deleted"

# Delete @snapshots subvolume (no longer needed)
btrfs subvolume delete /mnt/@snapshots 2>/dev/null || echo "@snapshots not found or already deleted"
echo "@snapshots deleted (if it existed)"

# Delete @root-blank (replaced by @blank)
btrfs subvolume delete /mnt/@root-blank
echo "@root-blank deleted"

# Delete @persist (replaced by @persist-root)
btrfs subvolume delete /mnt/@persist
echo "@persist deleted"

# Delete old-root-backup if it exists (leftover from previous migrations)
btrfs subvolume delete /mnt/@old-root-backup 2>/dev/null || echo "No old-root-backup to delete"
```

#### Step 5.5: Verify Final State
```bash
# List final subvolumes
echo "=== Final Subvolume List ==="
btrfs subvolume list /mnt

# Should see:
# - @ (root, recreated on every boot)
# - @blank (in use by new config)
# - @nix (persistent)
# - @persist-root (in use by new config)
# - @persist-dotfiles (in use by new config)
# - @persist-userfiles (in use by new config)
# - @home-backup (kept as safety backup)

# Should NOT see:
# - @home (deleted)
# - @snapshots (deleted)
# - @root-blank (deleted)
# - @persist (deleted)
```

#### Step 5.6: Unmount and Reboot
```bash
# Unmount
cd /
umount /mnt

# Reboot to installed system
reboot
```

**After this reboot, verify everything still works:**
```bash
# Check boot worked correctly
mount | grep persist

# Verify data is still accessible
ls ~/.ssh
ls ~/nixos-config
ls ~/.config/plasma*

# Test a reboot to ensure everything is stable
sudo reboot
```

#### Step 5.7: Delete Backup (Optional, After Extended Testing)
**Only after weeks of confirmed stable operation:**

```bash
# Boot from live USB one more time
mount -t btrfs -o subvolid=5 /dev/disk/by-uuid/a895216b-d275-480c-9b78-04c6a00df14a /mnt

# Delete the @home-backup subvolume
btrfs subvolume delete /mnt/@home-backup

# Unmount
umount /mnt
```

**Keep the Clonezilla disk image indefinitely as ultimate disaster recovery.**

---

## Boot Sequence with Home Impermanence

```
1. Kernel boots, discovers devices
2. initramfs runs boot.initrd.postDeviceCommands:
   a. Wipes @ (root) → recreates from @blank
   b. Creates /home/joemitz directory structure on fresh @
3. initramfs mounts filesystems with neededForBoot:
   - / (fresh @, contains /home directory)
   - /nix (@nix - persistent)
   - /persist-root (@persist-root - persistent)
   - /persist-dotfiles (@persist-dotfiles - persistent)
   - /persist-userfiles (@persist-userfiles - persistent)
4. Root filesystem transitions from initramfs to real root
5. Activation scripts run:
   - impermanence module creates bind mounts:
     * /persist-root → @ (system state)
     * /persist-dotfiles/joemitz → /home/joemitz (dotfiles)
     * /persist-userfiles/joemitz → /home/joemitz (userfiles)
6. sops-nix decrypts secrets to /home/joemitz/.config/secrets.env
   - This works because .config is bind-mounted from /persist-dotfiles
7. Services start, user can login
```

---

## Rollback Plan

If home impermanence causes issues, you can roll back:

### Option 1: Boot Previous Generation (Easiest)

At the systemd-boot bootloader screen:
1. Select the previous NixOS generation (before home-impermanence changes)
2. Boot into it - will work because `@root-blank`, `@persist`, and `@home` still exist
3. Once booted, revert configuration:
   ```bash
   cd ~/nixos-config
   git checkout main  # or: git revert <commit-hash>
   nhs  # Rebuild with old config
   ```

### Option 2: Live USB Recovery

```bash
# Boot NixOS Live USB
mount -t btrfs -o subvolid=5 /dev/disk/by-uuid/a895216b-d275-480c-9b78-04c6a00df14a /mnt

# If after Phase 5 (old subvolumes deleted), restore from copies:
btrfs subvolume snapshot /mnt/@home-backup /mnt/@home
btrfs subvolume snapshot /mnt/@blank /mnt/@root-blank
btrfs subvolume snapshot /mnt/@persist-root /mnt/@persist
btrfs subvolume create /mnt/@snapshots

# Unmount and reboot
umount /mnt
reboot
```

Then boot previous generation and revert config as in Option 1.

---

## Testing Checklist

### Phase 1: Preparation
- [ ] Full Clonezilla disk image backup created
- [ ] Created home-impermanence branch and pushed to remote

### Phase 2: Configuration Updates (Current System - DON'T REBOOT)
- [ ] /home mount removed from hardware-configuration.nix
- [ ] /.snapshots mount removed from hardware-configuration.nix
- [ ] /persist renamed to /persist-root in hardware-configuration.nix
- [ ] /persist-dotfiles mount added to hardware-configuration.nix
- [ ] /persist-userfiles mount added to hardware-configuration.nix
- [ ] Boot script updated in configuration.nix (uses @blank, creates /home/joemitz)
- [ ] environment.persistence."/persist" renamed to "/persist-root"
- [ ] environment.persistence."/persist-dotfiles" added with BROAD .config/.local persistence
- [ ] environment.persistence."/persist-userfiles" added
- [ ] "root" Snapper config removed
- [ ] "home" Snapper config removed
- [ ] "persist" Snapper config renamed to "persist-root"
- [ ] "persist-dotfiles" Snapper config added
- [ ] "persist-userfiles" Snapper config added
- [ ] Borg backup paths updated (optional)
- [ ] `nh os boot` succeeded (DO NOT REBOOT YET)

### Phase 3: Live USB - Subvolumes & Migration
- [ ] Booted from NixOS Live USB
- [ ] @blank created as snapshot of @root-blank
- [ ] @persist-root created as snapshot of @persist
- [ ] @home-backup snapshot created
- [ ] @persist-dotfiles subvolume created
- [ ] @persist-userfiles subvolume created
- [ ] All dotfiles migrated to @persist-dotfiles
- [ ] All userfiles migrated to @persist-userfiles
- [ ] Critical files verified (SSH keys, Age keys, nixos-config)
- [ ] New subvolumes verified
- [ ] Old subvolumes still exist (@root-blank, @persist, @home)
- [ ] Rebooted to installed system with new config

### Phase 4: Verification
- [ ] First reboot successful
- [ ] /persist-root, /persist-dotfiles, /persist-userfiles mounted
- [ ] /home is a directory on @ (NOT a separate mount)
- [ ] All bind mounts present
- [ ] SSH keys accessible
- [ ] Age key accessible
- [ ] sops-nix secrets decrypt correctly
- [ ] Git credentials work
- [ ] Claude Code works
- [ ] Firefox profile intact
- [ ] Kate settings preserved
- [ ] KDE Plasma settings intact (panels, widgets, shortcuts)
- [ ] Projects accessible
- [ ] Snapper configs correct (only persist-root, persist-dotfiles, persist-userfiles)
- [ ] Ephemeral test file wiped after reboot
- [ ] Persistent files remain after reboot
- [ ] System stable for several days

### Phase 5: Cleanup (After Days of Testing)
- [ ] Booted from Live USB
- [ ] Nested @home snapshots deleted
- [ ] @home subvolume deleted
- [ ] @snapshots subvolume deleted
- [ ] @root-blank deleted
- [ ] @persist deleted
- [ ] Final subvolume list verified
- [ ] Rebooted and system still works
- [ ] @home-backup kept for extended period
- [ ] Clonezilla backup kept indefinitely

---

## Key Improvements in This Revision

1. **✅ Fixed Boot Script Timing:** Uses snapshot approach - creates `@blank` and `@persist-root` as copies of originals, both coexist during testing
2. **✅ Broad KDE Persistence:** Persists entire `.config`, `.local/share`, `.local/state` directories for full KDE compatibility
3. **✅ Fixed Nested Snapshot Cleanup:** Deletes nested snapshots in `@home/.snapshots` before deleting `@home`
4. **✅ Clearer Phase Structure:** Reorganized to make it obvious when to reboot
5. **✅ Added Verification Steps:** Critical file verification after data migration in Phase 3
6. **✅ Rollback-Friendly:** Old and new subvolumes coexist until Phase 5, previous generations boot successfully

---

## Notes & Warnings

⚠️ **CRITICAL:**
- **CREATE FULL DISK IMAGE WITH CLONEZILLA BEFORE STARTING!**
- Back up Age key externally (`~/.config/sops/age/keys.txt`)
- Keep `@home-backup` for at least a week
- Keep Clonezilla image indefinitely

⚠️ **Boot Order:**
- Persist subvolumes MUST have `neededForBoot = true`
- Home wipe happens in initrd, before normal mounts
- Impermanence bind mounts happen during activation

⚠️ **Snapshot Approach:**
- Old and new subvolumes coexist until Phase 5
- Previous generations continue to work
- Disk space cost is minimal (empty snapshots are <1MB, @persist-root is shared data)
