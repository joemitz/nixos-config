# Home Impermanence Implementation Plan

## Overview
Implement home directory impermanence by wiping `/home` (@home subvolume) on every boot and restoring persistent data from two new subvolumes: `@persist-dotfiles` for configuration files and `@persist-userfiles` for user documents/projects.

## Architecture

### Current State
- `@home` subvolume mounted at `/home` with `neededForBoot = true` (fully persistent)
- Root impermanence working: `@` wiped on boot, recreated from `@root-blank`
- System state persisted via `@persist` with impermanence module bind mounts

### Target State
```
Btrfs Filesystem (a895216b-d275-480c-9b78-04c6a00df14a)
├── @                      (/) - WIPED ON BOOT, recreated from @root-blank
├── @root-blank            Reference snapshot (pristine @)
├── @home                  (/home) - WIPED ON BOOT, recreated from @home-blank  ← NEW
├── @home-blank            Reference snapshot (pristine /home skeleton)        ← NEW
├── @home-backup           Safety backup of current @home before migration     ← NEW (temporary)
├── @nix                   (/nix) - Persistent
├── @persist               (/persist) - Persistent (system state)
├── @persist-dotfiles      (/persist-dotfiles) - Persistent (user dotfiles)   ← NEW
├── @persist-userfiles     (/persist-userfiles) - Persistent (user files)     ← NEW
└── @snapshots             (/.snapshots) - Persistent
```

## Persistence Strategy

### Dotfiles → @persist-dotfiles (mounted at /persist-dotfiles)
Any path starting with `.` goes here. Bind mounted to `/home/joemitz/.<name>`.

**Critical (must persist):**
- `.ssh/` (SSH keys, known_hosts) - CRITICAL for remote access
- `.git-credentials` - Git credential store
- `.claude/` (45M) - Claude Code data
- `.claude.json`, `.claude.json.backup` - Claude config
- `.config/` (1.4G) - Application configurations
  - Specific subdirs: `alacritty/`, `kate/`, `git/`, `gh/`, `borg/`, `environment.d/`, `gtk-3.0/`, `gtk-4.0/`, `guvcview2/`, `micro/`, KDE configs
- `.local/share/` (469M) - User application data
- `.local/state/` (688K) - Application state
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

No code changes needed. Information gathering complete.

---

### Phase 2: Create Subvolumes & Migrate Data (Live USB Required)

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

#### Step 2.6: Create @home-blank Snapshot
```bash
# Delete everything from @home (we have backups!)
cd /mnt
btrfs subvolume delete @home

# Create minimal @home-blank with skeleton structure
btrfs subvolume create @home-blank
mkdir -p @home-blank/joemitz
chown 1000:100 @home-blank/joemitz
chmod 700 @home-blank/joemitz

# Create fresh @home from @home-blank for first boot
btrfs subvolume snapshot @home-blank @home
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
**Location:** Lines after line 53

Add filesystem entries for new persist subvolumes:

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

**Change existing /home entry** (line 22-27):
```nix
# BEFORE:
fileSystems."/home" =
  { device = "/dev/disk/by-uuid/a895216b-d275-480c-9b78-04c6a00df14a";
    fsType = "btrfs";
    options = [ "subvol=@home" "compress=zstd" "noatime" "space_cache=v2" ];
    neededForBoot = true;  # KEEP THIS - needed for impermanence bind mounts
  };
```

No change needed to /home mount - it still needs `neededForBoot = true` so impermanence can bind mount into it.

---

#### File: `configuration.nix`

**Change 1: Add Home Wipe to Boot Script** (after line 50, inside boot.initrd.postDeviceCommands)

```nix
boot.initrd.postDeviceCommands = pkgs.lib.mkAfter ''
  mkdir -p /mnt

  # Mount the btrfs root to /mnt for subvolume manipulation
  mount -t btrfs -o subvolid=5 /dev/disk/by-uuid/a895216b-d275-480c-9b78-04c6a00df14a /mnt

  # === ROOT WIPE (existing) ===
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
  btrfs subvolume snapshot /mnt/@root-blank /mnt/@

  # === HOME WIPE (new) ===
  # Delete all nested subvolumes recursively before removing home
  while btrfs subvolume list -o /mnt/@home | grep -q .; do
    btrfs subvolume list -o /mnt/@home |
    cut -f9 -d' ' |
    while read subvolume; do
      echo "deleting /$subvolume subvolume..."
      btrfs subvolume delete "/mnt/$subvolume" || true
    done
  done

  echo "deleting /@home subvolume..."
  btrfs subvolume delete /mnt/@home

  echo "restoring blank /@home subvolume..."
  btrfs subvolume snapshot /mnt/@home-blank /mnt/@home

  # Unmount and continue boot process
  umount /mnt
'';
```

**Change 2: Add Home Impermanence Config** (after line 233, after existing environment.persistence)

```nix
# Home impermanence - dotfiles
environment.persistence."/persist-dotfiles" = {
  hideMounts = true;

  users.joemitz = {
    directories = [
      ".ssh"
      ".claude"
      ".config"
      ".local"
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

**Change 3: Add Snapper Configs** (after line 360, inside services.snapper.configs)

```nix
services.snapper = {
  configs = {
    # ... existing root, home, persist configs ...

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

**Change 4: Update Borg Backup** (optional, around line 290)

Add new persist subvolumes to Borg backup paths (if desired):

```nix
paths = [
  "/persist"
  "/persist-dotfiles"      # Add this
  "/persist-userfiles"     # Add this
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
sudo snapper -c persist-dotfiles list
sudo snapper -c persist-userfiles list
# Should show snapshots being created
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

1. **hardware-configuration.nix** (lines 53+)
   - Add `/persist-dotfiles` filesystem entry with `neededForBoot = true`
   - Add `/persist-userfiles` filesystem entry with `neededForBoot = true`

2. **configuration.nix** (multiple locations)
   - Lines 24-50: Update `boot.initrd.postDeviceCommands` to add home wipe logic
   - After line 233: Add two new `environment.persistence` blocks (dotfiles + userfiles)
   - After line 360: Add two new Snapper configs
   - Around line 290 (optional): Update Borg backup paths

---

## Boot Sequence with Home Impermanence

```
1. Kernel boots, discovers devices
2. initramfs runs boot.initrd.postDeviceCommands:
   a. Wipes @ (root) → recreates from @root-blank
   b. Wipes @home → recreates from @home-blank ← NEW
3. initramfs mounts filesystems with neededForBoot:
   - / (fresh @)
   - /home (fresh @home)
   - /nix (@nix - persistent)
   - /persist (@persist - persistent)
   - /persist-dotfiles (@persist-dotfiles - persistent) ← NEW
   - /persist-userfiles (@persist-userfiles - persistent) ← NEW
   - /.snapshots (@snapshots - persistent)
4. Root filesystem transitions from initramfs to real root
5. Activation scripts run:
   - impermanence module creates bind mounts:
     * /persist → @ (system state)
     * /persist-dotfiles/joemitz → /home/joemitz (dotfiles) ← NEW
     * /persist-userfiles/joemitz → /home/joemitz (userfiles) ← NEW
6. sops-nix decrypts secrets to /home/joemitz/.config/secrets.env
   - This works because .config is bind-mounted from /persist-dotfiles
7. Services start, user can login
```

---

## sops-nix Compatibility

**Important:** sops-nix will continue to work because:
- `/home/joemitz/.config/secrets.env` is where secrets are written
- `.config` will be bind-mounted from `/persist-dotfiles/joemitz/.config`
- Age keys at `~/.config/sops/age/keys.txt` will persist (in `.config`)
- No changes needed to sops configuration!

---

## Rollback Plan

If home impermanence causes issues:

1. **Boot from live USB**
2. **Mount filesystem:**
   ```bash
   mount -t btrfs -o subvolid=5 /dev/disk/by-uuid/a895216b-d275-480c-9b78-04c6a00df14a /mnt
   ```
3. **Restore from backup:**
   ```bash
   btrfs subvolume delete /mnt/@home
   btrfs subvolume snapshot /mnt/@home-backup /mnt/@home
   ```
4. **Revert config changes** (remove new persistence blocks, remove home wipe from boot script)
5. **Rebuild and reboot**

---

## Estimated Disk Usage

- **@persist-dotfiles:** ~8-9 GB (configs + selective caches)
- **@persist-userfiles:** Varies (projects, documents, media)
- **@home-blank:** <1 MB (empty skeleton)
- **@home-backup:** Same as current /home (keep temporarily for safety)

---

## Testing Checklist

- [ ] Subvolumes created successfully
- [ ] Data migrated to @persist-dotfiles and @persist-userfiles
- [ ] @home-blank created with minimal skeleton
- [ ] Configuration changes applied
- [ ] `nixos-rebuild boot` succeeds
- [ ] First reboot successful
- [ ] All bind mounts present (`findmnt` check)
- [ ] SSH keys accessible
- [ ] Git credentials work
- [ ] Claude Code config intact
- [ ] Firefox profile accessible
- [ ] Kate settings preserved
- [ ] Projects (anova, nixos-config) accessible
- [ ] Ephemeral test file disappears after reboot
- [ ] Snapper creating snapshots for new subvolumes
- [ ] Borg backup working (if enabled)
- [ ] sops-nix secrets still decrypt correctly

---

## Notes & Warnings

⚠️ **CRITICAL:**
- Back up important data before starting (especially Age key at `~/.config/sops/age/keys.txt`)
- Keep `@home-backup` subvolume for at least a week after successful migration
- Test thoroughly before deleting backup

⚠️ **Boot Order is Critical:**
- Persist subvolumes MUST have `neededForBoot = true`
- Home wipe happens in initrd, before normal mounts
- Impermanence bind mounts happen during activation, after filesystems are mounted

⚠️ **Narrow Persistence:**
- The plan lists specific paths; any unlisted paths will NOT persist
- You can add more paths later by editing the persistence blocks and rebuilding
- Start narrow, expand as needed

⚠️ **Cache Strategy:**
- Large caches (.gradle 3.7G, .npm 226M) are persisted for build performance
- Browser/UI caches are NOT persisted (auto-regenerate quickly)
- Adjust based on your preferences after testing
