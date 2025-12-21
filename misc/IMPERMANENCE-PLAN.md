# NixOS Impermanence Implementation Plan

## Overview
Implement full system impermanence where both root (/) and /home are wiped on every boot. Only explicitly declared paths will persist across reboots. Secrets will be managed with agenix (encrypted in git).

## Quick Summary
- **Method**: Boot-time Btrfs subvolume deletion (wipe @ and @home, recreate fresh)
- **Subvolume Structure**: Clean 4-subvolume layout (@ @home @nix @persist)
- **Critical First Step**: Restructure subvolumes from live USB (create @nix, @persist, remove nested junk)
- **Files Modified**: hardware-configuration.nix, flake.nix, configuration.nix (home.nix unchanged)
- **Persistence Approach**: NixOS impermanence module only (NOT home-manager impermanence)
- **Testing Approach**: Incremental (8 stages) - restructure first, test persistence before enabling wiping
- **Secrets**: Initially persist directly, agenix can be added later
- **Safety**: Full backup required, live USB essential, rollback via bootloader generations

## User Requirements
- **Scope**: Full impermanence - wipe both / and /home on reboot
- **Secrets**: Use agenix for encrypted secrets in git
- **Storage**: Create /persist on root Btrfs partition (new @persist subvolume)
- **Keep**: /mnt/nvme remains as separate data storage
- **Root Strategy**: Boot-time Btrfs subvolume deletion (delete & recreate @ and @home on boot)
- **Logs**: Persistent (/var/log kept in /persist)
- **Projects**: Keep in /home/joemitz with explicit persistence declarations
- **Cache**: Ephemeral (wiped on reboot for clean slate)

## Current System State
- Root device: UUID a895216b-d275-480c-9b78-04c6a00df14a (Btrfs)
- Current subvolumes: @ (root), @home (home), srv, var/lib/portables, var/lib/machines, tmp, var/tmp
- Boot: systemd-boot on vfat partition
- Desktop: KDE Plasma 6 with SDDM
- Key services: NetworkManager, OpenSSH, CUPS, PipeWire

## Implementation Steps

### Phase 0: Subvolume Restructuring (CRITICAL - Do First!)

**Current subvolumes (messy):**
- @ (root), @home (home)
- srv, var/lib/portables, var/lib/machines, tmp, var/tmp (nested in @, will survive wipes!)

**Target subvolumes (clean):**
- @ (root) - ephemeral, wiped on boot
- @home (home) - ephemeral, wiped on boot
- @nix (nix store) - persistent, NEVER wiped (critical for boot speed!)
- @persist (user/system data) - persistent, NEVER wiped

**Why @nix is critical**: Without it, /nix/store gets wiped with @ and you'd rebuild the entire system on every boot!

**Procedure from Live USB** (safest):
```bash
# Boot from NixOS live USB
sudo su
mkdir /mnt/root
mount -o subvol=/ /dev/disk/by-uuid/a895216b-d275-480c-9b78-04c6a00df14a /mnt/root
cd /mnt/root

# 1. Create @nix subvolume and move nix store
btrfs subvolume create @nix
cp -a @/nix/. @nix/
# Verify copy succeeded before continuing!
ls -la @nix/store  # Should see lots of packages

# 2. Create @persist subvolume
btrfs subvolume create @persist
mkdir -p @persist/home

# 3. Delete unnecessary nested subvolumes
btrfs subvolume delete @/srv
btrfs subvolume delete @/var/lib/portables
btrfs subvolume delete @/var/lib/machines
btrfs subvolume delete @/tmp
btrfs subvolume delete @/var/tmp

# 4. Remove old nix from @ (now that it's in @nix)
rm -rf @/nix

# 5. Unmount and reboot into system
cd /
umount /mnt/root
reboot
```

**Alternative: From running system** (more risky but possible):
```bash
# Boot into single-user mode or use systemd-inhibit
sudo su
mkdir /mnt/root
mount -o subvol=/ /dev/disk/by-uuid/a895216b-d275-480c-9b78-04c6a00df14a /mnt/root

# Same steps as above, but be careful - nix store is in use!
# Recommend using live USB instead for safety
```

**After restructuring, update hardware-configuration.nix IMMEDIATELY** (before next reboot):
```nix
fileSystems."/nix" = {
  device = "/dev/disk/by-uuid/a895216b-d275-480c-9b78-04c6a00df14a";
  fsType = "btrfs";
  options = [ "subvol=@nix" ];
};
```

Then rebuild: `sudo nixos-rebuild boot` (not switch! We need to reboot)

### Phase 1: Backup and Preparation
1. **Backup critical data** (user must do this before Phase 0):
   - Copy /home/joemitz to /mnt/nvme/home-backup-$(date +%Y%m%d)
   - Export SSH keys, git credentials, GitHub token
   - Document any other important state
   - **This backup is critical** - subvolume restructuring is risky!

2. **Have recovery tools ready**:
   - NixOS live USB ready
   - Know how to boot from USB
   - Understand Btrfs basics for recovery

### Phase 2: Add Flake Inputs
**File**: `flake.nix`

Add two new inputs to the inputs section:
```nix
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  home-manager = {
    url = "github:nix-community/home-manager";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  claude-code.url = "github:sadjow/claude-code-nix";
  impermanence.url = "github:nix-community/impermanence";
  agenix = {
    url = "github:ryantm/agenix";
    inputs.nixpkgs.follows = "nixpkgs";
  };
};
```

Update outputs to pass inputs to modules:
```nix
outputs = { self, nixpkgs, home-manager, claude-code, impermanence, agenix, ... }: {
  nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      ./configuration.nix
      impermanence.nixosModules.impermanence
      agenix.nixosModules.default
      home-manager.nixosModules.home-manager
      {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.users.joemitz = import ./home.nix;
        home-manager.extraSpecialArgs = { inherit claude-code; };
      }
    ];
  };
};
```

Note: We don't pass impermanence to home-manager since we won't use the home-manager impermanence module.

### Phase 3: Configure Hardware Mounts
**File**: `hardware-configuration.nix`

Add /nix and /persist mount points:
```nix
fileSystems."/nix" = {
  device = "/dev/disk/by-uuid/a895216b-d275-480c-9b78-04c6a00df14a";
  fsType = "btrfs";
  options = [ "subvol=@nix" ];
};

fileSystems."/persist" = {
  device = "/dev/disk/by-uuid/a895216b-d275-480c-9b78-04c6a00df14a";
  fsType = "btrfs";
  options = [ "subvol=@persist" ];
  neededForBoot = true;  # Critical for impermanence to work
};
```

Note: The /nix mount should already be added in Phase 0 immediately after creating the @nix subvolume.

Root and home will use boot-time Btrfs subvolume wiping (configured in Phase 7).

### Phase 4: System and User Persistence (All in configuration.nix)
**File**: `configuration.nix`

Add complete impermanence configuration (system + user in one place):
```nix
environment.persistence."/persist" = {
  hideMounts = true;

  # System-level directories
  directories = [
    "/etc/NetworkManager/system-connections"
    "/var/lib/NetworkManager"
    "/var/lib/bluetooth"
    "/var/lib/systemd/coredump"
    "/var/lib/sddm"
    "/var/lib/cups"
    "/var/log"
    "/var/db/sudo/lectured"
  ];

  # System-level files
  files = [
    "/etc/machine-id"
    "/etc/ssh/ssh_host_ed25519_key"
    "/etc/ssh/ssh_host_ed25519_key.pub"
    "/etc/ssh/ssh_host_rsa_key"
    "/etc/ssh/ssh_host_rsa_key.pub"
  ];

  # User-level persistence (using users.<name> option)
  users.joemitz = {
    directories = [
      # Development
      "nixos-config"  # This repository
      # Add other project directories as needed

      # SSH and Git
      ".ssh"
      ".config/gh"

      # Claude Code
      ".claude"

      # Application data
      ".config/VSCodium"
      ".config/Postman"
      ".zoom"
      ".mozilla"

      # KDE Plasma settings
      ".config/plasma-workspace"
      ".config/plasmashellrc"
      ".config/plasmarc"
      ".config/kdeglobals"
      ".config/kwinrc"
      ".config/kwinrulesrc"
      ".local/share/kwalletd"
      ".local/share/dolphin"
      ".local/share/kate"
      ".local/share/konsole"

      # Application state (selective)
      ".local/share/applications"
      ".local/share/keyrings"

      # User directories
      "Downloads"
      "Documents"
      "Pictures"
    ];

    files = [
      ".bash_history"
      ".git-credentials"
    ];
  };
};
```

Note: All persistence (system + user) is now declared in configuration.nix using the stable NixOS impermanence module.

### Phase 5: Home-Manager Configuration
**File**: `home.nix`

**No changes needed!** home.nix stays exactly as-is with all your existing configuration:
- programs.git configuration
- programs.tmux configuration
- programs.bash configuration
- User packages (claude-code, gh, tmux, vscodium, postman, zoom-us)

User persistence is now declared in configuration.nix (Phase 4), not in home.nix. This is the more stable approach recommended by the community.

### Phase 6: Agenix Secret Management (Optional - Can be done later)

Agenix setup can be deferred to Phase 9 refinement. For initial implementation:
- Persist secrets directly in /persist (less ideal but simpler to start)
- SSH keys: persisted via impermanence declarations
- Git credentials: persisted via impermanence declarations

**If implementing agenix now**:
1. Create `secrets/secrets.nix`:
```nix
let
  joemitz = "ssh-ed25519 AAAAC3... joemitz@nixos";  # Your public key
in {
  "git-credentials.age".publicKeys = [ joemitz ];
  "github-token.age".publicKeys = [ joemitz ];
}
```

2. Encrypt secrets:
```bash
# Install agenix CLI
nix run github:ryantm/agenix -- -e secrets/git-credentials.age
```

3. Configure decryption in configuration.nix:
```nix
age.secrets.git-credentials = {
  file = ./secrets/git-credentials.age;
  path = "/home/joemitz/.git-credentials";
  owner = "joemitz";
  mode = "600";
};
```

**Recommendation**: Skip agenix for initial implementation, add later once impermanence is working.

### Phase 7: Configure Boot-Time Wiping
**File**: `configuration.nix`

Add at the top of configuration.nix:
```nix
{ config, pkgs, lib, ... }:
```

Then add boot wiping configuration:
```nix
boot.initrd.postDeviceCommands = lib.mkAfter ''
  mkdir /btrfs_tmp
  mount /dev/disk/by-uuid/a895216b-d275-480c-9b78-04c6a00df14a /btrfs_tmp
  if [[ -e /btrfs_tmp/@ ]]; then
      mkdir -p /btrfs_tmp/old_roots
      timestamp=$(date --date="@$(stat -c %Y /btrfs_tmp/@)" "+%Y-%m-%-d_%H:%M:%S")
      mv /btrfs_tmp/@ "/btrfs_tmp/old_roots/$timestamp"
      btrfs subvolume delete "/btrfs_tmp/old_roots/$timestamp"
  fi
  if [[ -e /btrfs_tmp/@home ]]; then
      mkdir -p /btrfs_tmp/old_homes
      timestamp=$(date --date="@$(stat -c %Y /btrfs_tmp/@home)" "+%Y-%m-%-d_%H:%M:%S")
      mv /btrfs_tmp/@home "/btrfs_tmp/old_homes/$timestamp"
      btrfs subvolume delete "/btrfs_tmp/old_homes/$timestamp"
  fi

  btrfs subvolume create /btrfs_tmp/@
  btrfs subvolume create /btrfs_tmp/@home
  umount /btrfs_tmp
'';
```

**IMPORTANT**: Don't enable this until after testing persistence declarations work correctly!

### Phase 8: Testing Strategy (CRITICAL - Follow This Order!)

**Stage 0: Subvolume restructuring** (See Phase 0 above)
- This must be done FIRST, before any config changes
- Creates @nix, @persist subvolumes
- Removes unnecessary nested subvolumes
- Most risky step - have backups and live USB ready!

**Stage 1: Verify subvolume structure**
```bash
# After Phase 0 and reboot, verify clean structure
sudo btrfs subvolume list /
# Should show: @, @home, @nix, @persist only

# Verify mounts
mount | grep btrfs
# Should show @ on /, @home on /home, @nix on /nix

# Create persist directories
sudo mkdir -p /persist/home/joemitz
sudo chown -R joemitz:users /persist/home/joemitz
```

**Stage 2: Add flake inputs and /persist mount**
- Modify flake.nix (add inputs)
- Modify hardware-configuration.nix (add /persist mount - /nix already added in Phase 0)
- Run: `nhs` or `nh os switch /home/joemitz/nixos-config`
- Reboot and verify /persist is mounted: `mount | grep persist`

**Stage 3: Add persistence declarations WITHOUT wiping**
- Modify configuration.nix (add environment.persistence with users.joemitz section, NO boot wiping yet!)
- No changes to home.nix needed
- Run: `nhs`
- Check that symlinks are created: `ls -la ~/.ssh`, `ls -la /etc/ssh/`
- Verify bind mounts: `mount | grep persist`

**Stage 4: Manual migration**
```bash
# Copy critical data to persist
cp -r ~/.ssh /persist/home/joemitz/
cp -r ~/.config /persist/home/joemitz/
cp -r ~/.mozilla /persist/home/joemitz/
# ... copy other important directories
```

**Stage 5: Test without rebooting**
- Verify applications still work
- Check that persisted paths are accessible
- Ensure no broken symlinks

**Stage 6: Enable boot-time wiping (THE POINT OF NO RETURN)**
- Add boot.initrd.postDeviceCommands to configuration.nix
- Run: `nhs`
- **DO NOT REBOOT YET** - triple check everything is backed up

**Stage 7: First impermanent boot**
- Reboot
- Verify system boots correctly
- Check all applications work
- Verify persistent data is intact

**Rollback plan**:
- Boot into previous generation from bootloader menu
- Have live USB ready for emergency recovery
- Full backup on /mnt/nvme

### Phase 9: Refinement
After successful boot:
- Check what broke and add missing persistence declarations
- Monitor for applications that need additional state persisted
- Fine-tune what should be ephemeral vs persistent
- Consider adding agenix for better secret management
- Add any missing project directories to persistence
- Fine-tune KDE Plasma persistence (might need additional paths)

**Common issues and fixes**:
- Application won't start: Check logs, add missing ~/.config/ or ~/.local/share/ directory
- Settings not saved: Add specific config directory to persistence
- Login issues: Verify /var/lib/sddm is persisted
- Network profiles missing: Check /etc/NetworkManager/system-connections persists

## Critical Files to Modify
1. **Phase 0**: Subvolume restructuring via live USB (manual Btrfs commands)
2. `hardware-configuration.nix` - Add /nix mount (Phase 0) and /persist mount (Phase 3)
3. `flake.nix` - Add impermanence and agenix inputs
4. `configuration.nix` - Configure ALL persistence (system + user) and boot wiping
5. `home.nix` - NO CHANGES (keeps existing programs.* configuration)
6. Create `secrets/` directory with agenix configuration (optional, can be done later)

## Risks and Mitigations
- **Risk**: Subvolume restructuring fails, system unbootable
  - **Mitigation**: Do from live USB, have full backup, test mounting before rebooting
- **Risk**: /nix/store copy fails or incomplete
  - **Mitigation**: Verify copy with `ls -la`, compare sizes, keep original until verified
- **Risk**: Forgot to add /nix mount, system won't boot
  - **Mitigation**: Add /nix mount to hardware-configuration.nix BEFORE rebooting after Phase 0
- **Risk**: Forgot to persist something critical, system unbootable
  - **Mitigation**: Test incrementally, keep bootloader generations, have live USB
- **Risk**: Secrets not properly decrypted, can't login
  - **Mitigation**: Test agenix separately first, keep backup of secrets
- **Risk**: Data loss from wiping
  - **Mitigation**: Full backup before starting, test without wiping first
- **Risk**: Applications break due to missing state
  - **Mitigation**: Comprehensive persistence list, iterative refinement

## Why NixOS Impermanence Module (Not Home-Manager Module)
- **More stable**: Recommended by community as more reliable
- **Simpler debugging**: Everything in one place (configuration.nix)
- **Better maintained**: NixOS module has better support
- **Single source of truth**: All persistence declarations in configuration.nix

## Benefits After Implementation
- True declarative system - no configuration drift
- Clean slate on every boot - malware can't persist
- Forced good practices - explicit state management
- Easy system recovery - just reinstall with same config
- Better understanding of system state requirements
