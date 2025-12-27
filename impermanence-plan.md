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
├── @home (existing - persistent user data)
└── @nix (existing - persistent Nix store)
```

## Critical Files to Modify

### 1. `/home/joemitz/nixos-config/flake.nix`
- Add `impermanence.url = "github:nix-community/impermanence"` to inputs
- Add `impermanence` parameter to outputs
- Add `impermanence.nixosModules.impermanence` to modules list

### 2. `/home/joemitz/nixos-config/hardware-configuration.nix`
- Add new filesystem mount for /persist:
```nix
fileSystems."/persist" = {
  device = "/dev/disk/by-uuid/a895216b-d275-480c-9b78-04c6a00df14a";
  fsType = "btrfs";
  options = [ "subvol=@persist" "compress=zstd" "noatime" ];
  neededForBoot = true;  # CRITICAL: must mount before impermanence activation
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

  users.joemitz = {
    directories = [
      ".config/vorta"
      ".local/share/direnv"
      "Android"
      ".gradle"
      ".cache/devbox"
      ".mozilla"
      ".config/google-chrome"
      ".config/VSCodium"
      ".vscode-oss"
    ];

    files = [
      ".bash_history"
      ".alias"
    ];
  };
};
```

#### C. Disable Snapper for root (lines 259-269):
Remove the `root` configuration from `services.snapper.configs`, keep only `home` config.

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

# Create read-only blank snapshot of current root
btrfs subvolume snapshot -r /mnt/btrfs-root/@ /mnt/btrfs-root/@root-blank

# Verify
btrfs subvolume list /mnt/btrfs-root

# Unmount
umount /mnt/btrfs-root
```

### Phase 3: First Boot
1. Reboot into system
2. Watch boot logs: `journalctl -b | grep rollback`
3. Verify /persist mounted: `mount | grep persist`
4. Check services: `systemctl status sshd docker tailscaled NetworkManager`
5. Test SSH from remote machine (verify no host key warnings)
6. Test Docker: `docker ps`
7. Test Tailscale: `tailscale status`

### Phase 4: Validation
1. Create test file in /: `sudo touch /root/test-ephemeral.txt`
2. Create test file in /persist: `sudo touch /persist/test-persistent.txt`
3. Reboot
4. Verify /root/test-ephemeral.txt is GONE
5. Verify /persist/test-persistent.txt EXISTS
6. Run full workflow tests (Android dev, Docker, networking, secrets)

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

### User (joemitz)
- `.bash_history` - Command history
- `Android/` - Android SDK and keystores
- `.gradle`, `.cache/devbox` - Development caches
- `.config/VSCodium` - Editor settings

### Already Persistent (No Action Needed)
- `/home` - Entire home directory
- `/nix` - Nix store
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

## Risk Mitigations

### High Priority
- ✅ SSH host keys backed up and persisted
- ✅ /etc/machine-id persisted (required by many services)
- ✅ Tailscale state persisted (avoids re-authentication)
- ✅ Docker state persisted (avoids rebuilding containers)
- ✅ /persist mounts with `neededForBoot = true`

### Known Issues Addressed
- ✅ Snapper root config removed (incompatible with ephemeral root)
- ✅ Snapper home config kept (home remains persistent)
- ✅ WebStorm removed (not used)
- ✅ Sops age key in /home (already persistent)
- ✅ Git repo in /home (nhs alias continues working)

## Post-Implementation Checklist
- [ ] System boots without errors
- [ ] Rollback service runs successfully in initrd
- [ ] /persist is mounted
- [ ] SSH works remotely without host key warnings
- [ ] Tailscale connected
- [ ] Docker containers accessible
- [ ] WiFi connections persist after reboot
- [ ] Bluetooth devices remain paired
- [ ] Secrets loaded: `env | grep NPM_TOKEN`
- [ ] Test file in / disappears after reboot
- [ ] Test file in /persist survives reboot
- [ ] `nhs` alias works for auto-commit

## Benefits
- Clean system state on every boot (no cruft accumulation)
- Truly declarative system (only declared state persists)
- Easy recovery (always boots from known-good @root-blank)
- Confidence in configuration reproducibility

## Time Estimate
- Configuration changes: 1-2 hours
- Live boot subvolume creation: 30-60 minutes
- Testing and validation: 2-3 hours
- **Total: 4-6 hours**
