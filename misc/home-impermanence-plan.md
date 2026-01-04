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

### Phase 2: Update NixOS Configuration (Current System)

**Update configuration files BEFORE modifying subvolumes. This ensures the config and subvolume layout match when you boot.**

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

**Note:** Changed @root-blank → @blank. No separate home wipe - /home is just a directory on @ now!

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

**Change 4: Update Snapper Configs** (around line 323-360)

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

#### Step 2.1: Build New Boot Configuration

**Build the new boot configuration WITHOUT activating it yet:**
```bash
# This builds the new config and makes it available at next boot,
# but doesn't activate it now (system still uses current config)
nh os boot /home/joemitz/nixos-config

# Or if nh isn't working:
nixos-rebuild boot --flake /home/joemitz/nixos-config
```

**DO NOT REBOOT YET!** The new boot configuration is ready but the subvolumes don't match yet.

---

### Phase 3: Create Subvolumes & Migrate Data (Live USB Required)

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

#### Step 3.1: Mount Btrfs Root
```bash
# Mount the Btrfs root volume
mount -t btrfs -o subvolid=5 /dev/disk/by-uuid/a895216b-d275-480c-9b78-04c6a00df14a /mnt
cd /mnt
```

#### Step 3.2: Safety Backups
```bash
# Create snapshot backup of current @home (SAFETY)
btrfs subvolume snapshot /mnt/@home /mnt/@home-backup

# Create snapshot for Snapper (optional, for immediate rollback via Snapper)
mkdir -p /mnt/@home/.snapshots
btrfs subvolume snapshot /mnt/@home "/mnt/@home/.snapshots/pre-impermanence-$(date +%Y%m%d-%H%M%S)"
```

#### Step 3.3: Create New Persist Subvolumes
```bash
# Create dotfiles persist subvolume
btrfs subvolume create /mnt/@persist-dotfiles

# Create userfiles persist subvolume
btrfs subvolume create /mnt/@persist-userfiles

# Create base directory structure with proper ownership
mkdir -p /mnt/@persist-dotfiles/joemitz
mkdir -p /mnt/@persist-userfiles/joemitz
chown -R 1000:100 /mnt/@persist-dotfiles/joemitz  # joemitz:users (UID:GID)
chown -R 1000:100 /mnt/@persist-userfiles/joemitz
```

#### Step 3.4: Migrate Dotfiles to @persist-dotfiles
```bash
# Navigate to source directory
cd /mnt/@home/joemitz

# Copy critical configs first (fail if these don't exist - they're critical!)
echo "Copying critical configs..."
cp -a .ssh /mnt/@persist-dotfiles/joemitz/ || { echo "ERROR: .ssh not found!"; exit 1; }
cp -a .git-credentials /mnt/@persist-dotfiles/joemitz/ 2>/dev/null || echo "Warning: .git-credentials not found"
cp -a .claude /mnt/@persist-dotfiles/joemitz/ 2>/dev/null || echo "Warning: .claude not found"
cp -a .claude.json /mnt/@persist-dotfiles/joemitz/ 2>/dev/null || echo "Warning: .claude.json not found"
cp -a .claude.json.backup /mnt/@persist-dotfiles/joemitz/ 2>/dev/null || true

# Copy app configs (with error handling for missing directories)
echo "Copying application configs..."
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

#### Step 3.5: Migrate Userfiles to @persist-userfiles
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

#### Step 3.6: Verify Migration (CRITICAL!)
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

# Check subvolumes exist
echo "=== Current Subvolumes ==="
btrfs subvolume list /mnt

echo ""
echo "=== Verification complete! ==="
echo "If all checks passed, you can proceed to reboot."
echo "Otherwise, investigate errors before continuing!"
```

#### Step 3.7: Unmount and Reboot
```bash
# Unmount
cd /
umount /mnt

# Reboot to activate new configuration
echo "Rebooting to activate new configuration..."
reboot
```

**The new boot configuration (built in Phase 2) will activate on this reboot.**
**The @home subvolume still exists but won't be mounted - this is safe.**

---

### Phase 4: Verify New Configuration

**After rebooting from Phase 3, you should be running the new configuration. Now verify everything works.**

#### Step 4.1: Check Filesystem Mounts
```bash
# Check persist mounts are active
mount | grep persist
# Should see: /persist-root, /persist-dotfiles, /persist-userfiles

# Verify /home is NOT a separate mount (it's just a directory on @)
mount | grep "/home"
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

#### Step 4.4: Check Snapper Configs
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

#### Step 4.5: Test Application Settings
- Open Firefox - profile should be intact
- Open Kate - settings should be preserved
- Run `git config --global user.name` - should be your name
- Check KDE settings - may need reconfiguration (see note below about iterative config)

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
```

#### Step 4.7: Check Subvolume Status (Optional)
```bash
# From Live USB or by mounting the root subvolume:
# Verify @home still exists but isn't being used
sudo mount -t btrfs -o subvolid=5 /dev/disk/by-uuid/a895216b-d275-480c-9b78-04c6a00df14a /mnt
sudo btrfs subvolume list /mnt
# Should see @home in the list (but it's not mounted or used)
sudo umount /mnt
```

**If everything above checks out, proceed to Phase 5. Otherwise, troubleshoot issues before cleaning up.**

---

### Phase 5: Cleanup - Destructive Operations (After Days of Successful Testing)

**ONLY proceed with this phase after you've verified everything works perfectly for several days.**

This phase performs the destructive operations: renaming subvolumes and deleting the old @home and @snapshots subvolumes.

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

# You should see:
# - @root-blank (needs renaming to @blank)
# - @persist (needs renaming to @persist-root)
# - @home (needs deletion - no longer used)
# - @home-backup (keep for now)
# - @snapshots (needs deletion - no longer used)
# - @persist-dotfiles (already created and working)
# - @persist-userfiles (already created and working)
```

#### Step 5.4: Rename Subvolumes
```bash
# Rename @root-blank to @blank for clarity
mv /mnt/@root-blank /mnt/@blank

# Rename @persist to @persist-root for consistent naming
mv /mnt/@persist /mnt/@persist-root

# Verify renames worked
btrfs subvolume list /mnt | grep -E "@blank|@persist-root"
```

#### Step 5.5: Delete Unused Subvolumes
```bash
# Delete @home subvolume (we have @home-backup as safety!)
# /home is now just a directory on @ going forward
btrfs subvolume delete /mnt/@home
echo "@home deleted"

# Delete @snapshots subvolume (no longer needed - we only snapshot persist subvolumes)
btrfs subvolume delete /mnt/@snapshots
echo "@snapshots deleted"

# Clean out .snapshots directory from @home-backup if it exists
rm -rf /mnt/@home-backup/.snapshots 2>/dev/null || true

# Delete old-root-backup if it exists (leftover from previous migrations)
btrfs subvolume delete /mnt/@old-root-backup 2>/dev/null || echo "No old-root-backup to delete"
```

#### Step 5.6: Verify Final State
```bash
# List final subvolumes
echo "=== Final Subvolume List ==="
btrfs subvolume list /mnt

# Should see:
# - @ (root, recreated on every boot)
# - @blank (renamed from @root-blank)
# - @nix (persistent)
# - @persist-root (renamed from @persist)
# - @persist-dotfiles (new)
# - @persist-userfiles (new)
# - @home-backup (kept as safety backup)

# Should NOT see:
# - @home (deleted)
# - @snapshots (deleted)
# - @root-blank (renamed to @blank)
# - @persist (renamed to @persist-root)
```

#### Step 5.7: Unmount and Reboot
```bash
# Unmount
cd /
umount /mnt

# Reboot to installed system
reboot
```

**After this reboot, the system will use the renamed subvolumes (@blank instead of @root-blank).**

#### Step 5.8: Verify System Still Works
After rebooting, verify everything still works:
```bash
# Check boot worked correctly
mount | grep persist

# Verify data is still accessible
ls ~/.ssh
ls ~/nixos-config

# Test a reboot to ensure @blank works
sudo reboot
```

#### Step 5.9: Delete Backup (Optional, After Extended Testing)
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

## Boot Failure Recovery (Without Clonezilla)

If the system fails to boot after migration, here are recovery options at each stage:

### Recovery After Phase 3 (First Boot with New Config)

**Why this is the safest point:** Nothing has been deleted yet. @home, @root-blank, and @persist still exist with their original names.

#### Option 1: Boot Previous Generation (Easiest)

At the systemd-boot bootloader screen:

1. **Select the previous NixOS generation** (the one before your home-impermanence changes)
2. Boot into it
3. The old config expects @home subvolume - it still exists, so boot succeeds
4. Once booted, revert your configuration changes:
   ```bash
   cd ~/nixos-config
   git checkout main  # or: git revert <commit-hash>
   nhs  # Rebuild with old config
   ```

#### Option 2: Live USB Manual Fix

If generation boot doesn't work:

```bash
# Boot NixOS Live USB
mount -t btrfs -o subvolid=5 /dev/disk/by-uuid/a895216b-d275-480c-9b78-04c6a00df14a /mnt

# Mount system to investigate
mount -o subvol=@ /dev/disk/by-uuid/a895216b-d275-480c-9b78-04c6a00df14a /mnt
mount -o subvol=@nix /dev/disk/by-uuid/a895216b-d275-480c-9b78-04c6a00df14a /mnt/nix
mount -o subvol=@home /dev/disk/by-uuid/a895216b-d275-480c-9b78-04c6a00df14a /mnt/home
mount /dev/disk/by-uuid/F2B1-6D81 /mnt/boot

# Enter the system
nixos-enter

# Inside chroot, revert config and rebuild
cd /home/joemitz/nixos-config
git checkout main
nixos-rebuild boot

# Exit and reboot
exit
umount -R /mnt
reboot
```

### Recovery After Phase 5 (After Destructive Cleanup)

**Why this is trickier:** @home is deleted, subvolumes are renamed (@root-blank→@blank, @persist→@persist-root).

#### Step 1: Boot Live USB and Restore Subvolumes

```bash
# Boot NixOS Live USB
mount -t btrfs -o subvolid=5 /dev/disk/by-uuid/a895216b-d275-480c-9b78-04c6a00df14a /mnt
cd /mnt

# Restore @home from backup (CRITICAL!)
btrfs subvolume snapshot @home-backup @home
echo "@home restored from @home-backup"

# Restore old subvolume names to match old config
mv @blank @root-blank
echo "Renamed @blank back to @root-blank"

mv @persist-root @persist
echo "Renamed @persist-root back to @persist"

# Recreate @snapshots subvolume
btrfs subvolume create @snapshots
echo "@snapshots recreated"

# Verify subvolumes
echo "Current subvolumes:"
btrfs subvolume list /mnt

# Unmount and reboot
cd /
umount /mnt
reboot
```

#### Step 2: Boot Previous Generation

At bootloader, select the **previous generation** (before home-impermanence changes).

It will now boot successfully because:
- @home exists (restored from @home-backup)
- @root-blank exists (renamed from @blank)
- @persist exists (renamed from @persist-root)

#### Step 3: Make Old Config Permanent

Once booted into previous generation:

```bash
# Revert configuration changes in git
cd ~/nixos-config
git log  # Find the commit before home-impermanence changes
git reset --hard <commit-before-changes>

# Or if you want to keep git history:
git revert <bad-commit-hash>

# Rebuild to make old config the default
nhs

# Verify you're on old config
mount | grep home  # Should show /home mounted from @home subvolume
```

### Preventing Boot Failures

**Before starting Phase 5, verify generation rollback works:**

```bash
# List available generations
sudo nixos-rebuild list-generations

# You should see multiple generations like:
#   120  2024-01-15 10:30:00  (current)
#   119  2024-01-14 14:20:00
#   118  2024-01-13 09:15:00

# Test booting previous generation:
# 1. Reboot your system
# 2. At the bootloader menu, select generation 119 (or your previous one)
# 3. Verify it boots successfully
# 4. Reboot and return to current generation

# ONLY proceed with Phase 5 if previous generation boots successfully!
```

### Why This Migration Plan is Safe

**Multiple Safety Layers:**

1. **Until Phase 5:**
   - @home still exists (not deleted)
   - @home-backup exists (safety snapshot)
   - All old subvolumes intact
   - Previous generation boots immediately

2. **After Phase 5:**
   - @home-backup still exists (quick restore)
   - Previous generation available (select at boot)
   - Git history intact (revert config)
   - Clonezilla backup (nuclear option)

3. **At Every Stage:**
   - No single point of failure
   - Multiple recovery paths
   - Can always get back to working state

**Recovery Difficulty by Stage:**

- **Phase 1-2:** Trivial (just revert files, no subvolume changes)
- **Phase 3-4:** Easy (boot previous generation)
- **Phase 5:** Moderate (Live USB + restore subvolumes + boot previous generation)
- **Complete Disaster:** Use Clonezilla backup

---

## Estimated Disk Usage

- **@persist-dotfiles:** ~8-9 GB (configs + selective caches)
- **@persist-userfiles:** Varies (projects, documents, media)
- **@blank:** <1 MB (empty, shared by both @ and @home)
- **@home-backup:** Same as current /home (keep temporarily for safety)

---

## Testing Checklist

### Phase 1: Preparation
- [ ] Created home-impermanence branch and pushed to remote

### Phase 2: Configuration Updates (Current System)
- [ ] /home mount removed from hardware-configuration.nix
- [ ] /.snapshots mount removed from hardware-configuration.nix
- [ ] /persist renamed to /persist-root in hardware-configuration.nix
- [ ] /persist-dotfiles mount added to hardware-configuration.nix
- [ ] /persist-userfiles mount added to hardware-configuration.nix
- [ ] Boot script updated in configuration.nix (@root-blank → @blank, /home/joemitz creation)
- [ ] environment.persistence."/persist" renamed to "/persist-root"
- [ ] environment.persistence."/persist-dotfiles" added (user dotfiles config)
- [ ] environment.persistence."/persist-userfiles" added (user files config)
- [ ] "root" Snapper config removed (no snapshots for wiped subvolumes)
- [ ] "home" Snapper config removed
- [ ] "persist" Snapper config renamed to "persist-root"
- [ ] "persist-dotfiles" Snapper config added
- [ ] "persist-userfiles" Snapper config added
- [ ] Borg backup paths updated (optional)
- [ ] `nh os boot` or `nixos-rebuild boot` succeeds

### Phase 3: Subvolume Creation & Migration (Live USB)
- [ ] Full Clonezilla disk image backup created
- [ ] Booted from NixOS Live USB
- [ ] @home-backup snapshot created
- [ ] @persist-dotfiles subvolume created
- [ ] @persist-userfiles subvolume created
- [ ] All dotfiles migrated to @persist-dotfiles
- [ ] All userfiles migrated to @persist-userfiles
- [ ] Critical files verified (SSH keys, Age keys, nixos-config)
- [ ] Migration verification passed
- [ ] Rebooted to installed system with new config

### Phase 4: Verification (New Configuration Running)
- [ ] First reboot successful
- [ ] /persist-root, /persist-dotfiles, /persist-userfiles mounted
- [ ] /home is a directory on @ (NOT a separate mount)
- [ ] All bind mounts present (`findmnt -t btrfs | grep home`)
- [ ] SSH keys accessible (~/.ssh/id_*)
- [ ] Age key accessible (~/.config/sops/age/keys.txt)
- [ ] sops-nix secrets decrypt correctly
- [ ] Git credentials work
- [ ] Claude Code config intact (claude --version works)
- [ ] Firefox profile accessible
- [ ] Kate settings preserved
- [ ] Projects accessible (anova, nixos-config)
- [ ] Git operations work in nixos-config
- [ ] Snapper list-configs shows ONLY: persist-root, persist-dotfiles, persist-userfiles
- [ ] Snapper creating snapshots for all 3 persist subvolumes
- [ ] NO Snapper snapshots for / or /home
- [ ] Ephemeral test file created, rebooted, verified deleted
- [ ] Persistent files remain after reboot test
- [ ] Borg backup working (if enabled)
- [ ] System stable for several days

### Phase 5: Cleanup (After Days of Successful Testing)
- [ ] Booted from Live USB
- [ ] @root-blank renamed to @blank
- [ ] @persist renamed to @persist-root
- [ ] @home subvolume deleted
- [ ] @snapshots subvolume deleted
- [ ] .snapshots cleaned from @home-backup
- [ ] @old-root-backup deleted (if it existed)
- [ ] Final subvolume list verified
- [ ] Rebooted to installed system
- [ ] System still works with renamed subvolumes
- [ ] Another reboot test to ensure @blank works correctly
- [ ] @home-backup kept for extended period (weeks)
- [ ] Clonezilla backup kept indefinitely

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
