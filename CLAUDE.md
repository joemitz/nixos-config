# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a NixOS configuration repository using flakes and home-manager. The system is configured for user `joemitz` on hostname `nixos` running KDE Plasma 6 on x86_64-linux (AMD CPU + GPU). Claude Code is installed via a flake input from `github:sadjow/claude-code-nix`.

## Core Architecture

**Repository Structure**:
```
nixos-config/
├── flake.nix                   # Main flake entry point
├── .sops.yaml                  # Sops configuration
├── system/
│   ├── index.nix               # Main entry point (imports all modules)
│   ├── hardware-configuration.nix  # Hardware-specific configuration (auto-generated)
│   ├── boot.nix                # Boot loader, kernel, impermanence rollback
│   ├── hardware.nix            # AMD GPU, Bluetooth, firmware, filesystem mounts
│   ├── networking.nix          # Networking, firewall, SSH, Tailscale
│   ├── desktop.nix             # KDE Plasma, SDDM, audio, printing
│   ├── users.nix               # User accounts, timezone, locale, security
│   ├── secrets.nix             # Sops-nix secrets management
│   ├── services.nix            # Docker, ADB, NFS, NH, Nix settings
│   ├── persistence.nix         # Impermanence configuration (3 subvolumes)
│   └── backup.nix              # Snapper snapshots and Borg backups
├── home/
│   └── home.nix               # User-level home-manager configuration
├── cachix/
│   ├── default.nix            # Auto-imports all cachix configs
│   ├── claude-code.nix        # Claude Code binary cache
│   └── nix-community.nix      # Community binary cache
├── secrets/
│   ├── secrets.yaml           # Encrypted secrets (committed)
│   └── secrets-template.yaml  # Template (not committed)
└── pkgs/
    └── tiny4linux.nix         # Custom OBSBOT Tiny2 camera package
```

**Flake Structure**:
- `flake.nix`: Main entry point defining inputs (nixpkgs stable, home-manager, claude-code, sops-nix, tiny4linux, impermanence) and outputs
- `system/index.nix`: Main system configuration entry point (imports all system modules)
- `system/*.nix`: Modular system configuration split by concern (boot, hardware, networking, desktop, users, secrets, services, persistence, backup)
- `home/home.nix`: User-level home-manager configuration (user packages, git config, bash/tmux/alacritty settings)
- `system/hardware-configuration.nix`: Hardware-specific configuration with Btrfs subvolumes (generated, not typically edited manually)
- `pkgs/tiny4linux.nix`: Custom package for OBSBOT Tiny2 camera controller
- `cachix/`: Binary cache configurations (claude-code, nix-community)
- `secrets/`: Encrypted secrets managed by sops-nix

**Key Design Decisions**:
- Uses `nixos-25.11` stable channel
- home-manager integrated as a NixOS module (not standalone)
- Experimental features enabled: `nix-command` and `flakes`
- **Full system impermanence**: Root and home filesystems roll back to pristine state on every boot
- Important state persisted via three subvolumes: `/persist-root`, `/persist-dotfiles`, `/persist-userfiles`
- NH (Nix Helper) configured as modern replacement for nixos-rebuild
- Git hooks disabled globally (`core.hooksPath = "/dev/null"`)
- Auto-commits configuration changes after successful rebuilds via `nhs` alias
- Btrfs filesystem with compression (zstd) and snapshots via Snapper
- Automated backups via Borg to remote server
- LTS kernel to avoid AMD GPU bugs in newer kernels
- Binary caches configured: cache.nixos.org, claude-code.cachix.org, nix-community.cachix.org

## Building and Deploying

**Rebuild the system**:
```bash
nh os switch /home/joemitz/nixos-config
```

**Rebuild with auto-commit and push** (use the `nhs` bash alias):
```bash
nhs
```
This alias:
1. Switches to the config directory
2. Runs `nh os switch`
3. On success: auto-commits changes with generation number and timestamp
4. Pushes to git remote
5. Returns to original directory

**For Claude Code to run nhs**:
Since `nhs` is a bash alias, Claude must use interactive bash:
```bash
bash -ic "nhs"
```

**Update flake inputs**:
```bash
nix flake update
```

**Check flake**:
```bash
nix flake check
```

**Show flake info**:
```bash
nix flake show
```

## NH (Nix Helper) Configuration

NH is configured in services.nix with:
- Automatic weekly garbage collection
- Keeps last 10 generations and anything from last 10 days
- Flake path: `/home/joemitz/nixos-config`
- Download buffer size: 512 MiB for faster downloads

The activation script ensures proper file ownership to allow NH to update flake.lock without permission errors.

## Configuration Layout

**System Configuration** (modular structure in system/):
- **boot.nix**: systemd-boot with EFI, LTS kernel (pkgs.linuxPackages), root rollback on boot
- **hardware.nix**: AMD GPU with amdgpu driver early loading, hardware acceleration, Bluetooth, firmware updates, NVMe + NFS mounts
- **desktop.nix**: KDE Plasma 6 with SDDM (Wayland enabled, Opal wallpaper background), PipeWire audio, printing
- **networking.nix**: NetworkManager, Wake-on-LAN on enp6s0, Tailscale VPN, firewall, OpenSSH (port 22)
- **users.nix**: User accounts (joemitz, root), timezone (America/Los_Angeles), locale, polkit, sudo
- **secrets.nix**: Complete sops-nix configuration for encrypted secrets management
- **services.nix**: Docker, ADB for Android, NFS client, NH (Nix Helper), Nix experimental features
- **persistence.nix**: Impermanence configuration - root and home wipe on boot, state persisted to three subvolumes
- **backup.nix**: Snapper for Btrfs snapshots, Borg hourly backups to remote server (192.168.0.100)
- **Filesystem**: Btrfs with subvolumes (@, @nix, @blank, @persist-root, @persist-dotfiles, @persist-userfiles) and zstd compression

**User Configuration** (home/home.nix):
- CLI Tools: claude-code, gh, jq, tmux, patchelf, devbox, nodejs_24, micro
- Modern CLI Tools: btop (system monitor), eza (ls replacement), bat (cat replacement)
- Development: vscodium, postman, android-studio, android-tools, kate
- Applications: zoom-us, firefox, tidal-hifi, vlc, guvcview, remmina, vorta (backup)
- Custom Packages: tiny4linux (OBSBOT Tiny2 camera controller)
- Desktop Entries: guvcview with -z flag, tiny4linux-gui
- Git configured with useful aliases (co, st, br, hi, lb, ma, type, dump, pu, ad, ch)
- SSH with macbook host configuration
- Bash with tmux auto-attach, secrets sourcing, Android SDK paths, nhs alias
- Shell aliases: ls→eza, cat→bat, top→btop, code→codium, c→claude, nano→micro
- Tmux with custom keybindings (h/v for splits, n for new window, Ctrl+K to clear)
- Alacritty terminal with moonfly theme and pure black background
- direnv with nix-direnv integration

## Git Workflow

Git is configured with several useful aliases:
- `git co`: Quick commit (`git commit -m`)
- `git st`: Status
- `git br`: Branch
- `git hi`: Pretty log with graph and colors
- `git type`: Show object type (`cat-file -t`)
- `git dump`: Show object content (`cat-file -p`)
- `git pu`: Push
- `git ad`: Add
- `git ch`: Checkout
- `git lb`: Show last 10 branch checkouts with colors
- `git ma`: Show last 30 merge commits with colors

Auto-setup-remote is enabled for pushing new branches. Git LFS is configured. Credential helper uses store mode for persistence.

## Important Notes

- System state version: 25.11 (do not change without reading documentation)
- Home state version: 25.11
- Unfree packages are allowed system-wide
- The configuration auto-commits successfully applied changes to track system generations
- All .nix files and flake.lock have ownership fixed on activation to allow NH updates
- Using LTS kernel to avoid AMD GPU bug in 6.12.10+ (see https://bbs.archlinux.org/viewtopic.php?id=303556)
- AMD GPU driver loaded early in initrd for proper display detection before SDDM

## Hardware & Kernel

**AMD GPU Configuration**:
- Driver: amdgpu (loaded early in boot via initrd)
- Hardware acceleration enabled (32-bit support included)
- Video driver explicitly set to "amdgpu"

**Kernel**: LTS (linuxPackages) to avoid stability issues with newer kernels on AMD GPUs

**Filesystem**:
- Root filesystem: Btrfs with subvolumes (@, @nix, @blank, @persist-root, @persist-dotfiles, @persist-userfiles)
- Mount options: compress=zstd, noatime, space_cache=v2
- Root (@) subvolume: Rolls back to pristine @blank snapshot on every boot (stateless root)
- /persist-root: System state (NetworkManager, Docker, SSH keys, logs, etc.)
- /persist-dotfiles: User configs and application data (.config, .local, .ssh, .claude, etc.)
- /persist-userfiles: User documents and projects (nixos-config, anova, Documents, Downloads, etc.)
- All home files not explicitly persisted are wiped on reboot (stateless home)
- Additional NVMe drive mounted at /mnt/nvme (read-only)
- TrueNAS NFS share mounted at /mnt/truenas/plex (read-only)

**Snapper Snapshots**:
- Configured for persist-root, persist-dotfiles, and persist-userfiles
- Only snapshots persistent data (root and home are stateless, no point in snapshotting)
- All three configs have the same retention policy:
  - Hourly snapshots: 48 (2 days)
  - Daily snapshots: 7
  - Weekly snapshots: 4
  - Monthly snapshots: 12
  - Yearly snapshots: 2

## Development Environment

**Android Development**:
- Android Studio and android-tools installed
- ADB enabled system-wide
- Environment variables configured in home.nix:
  - ANDROID_HOME: $HOME/Android/Sdk
  - PATH includes emulator and platform-tools
  - ANDROID_RELEASE_KEY_ALIAS="release-key"
  - ANDROID_KEYSTORE_ALIAS="Anova"

**Docker**: Enabled with user in docker group

**Node.js**: Version 24 installed

**Additional Environment Variables**:
- NODE_ENV=development
- DEVICE_IP=192.168.0.249
- HUSKY=0 (disables git hooks)
- ANDROID_HOME=$HOME/Android/Sdk

## Secrets Management

This configuration uses [sops-nix](https://github.com/Mic92/sops-nix) to manage secrets securely.

**Files**:
- `secrets/secrets.yaml` - Encrypted secrets (safe to commit to git)
- `.sops.yaml` - sops configuration in root (safe to commit)
- `secrets/secrets-template.yaml` - Unencrypted template (NOT committed, in .gitignore)
- `/persist-dotfiles/home/joemitz/.config/sops/age/keys.txt` - Your age private key (NEVER commit! Back this up securely!)
- `~/.config/secrets.env` - Generated file sourced by bash (auto-created on rebuild)

**How It Works**:
1. Secrets stored encrypted in `secrets/secrets.yaml` using age encryption
2. On system activation, sops-nix decrypts and creates `~/.config/secrets.env`
3. Bash automatically sources this file, making secrets available as environment variables

**Editing Secrets**:
```bash
nix-shell -p sops --run "sops secrets/secrets.yaml"
```

**Adding New Secrets**:
1. Edit encrypted file: `nix-shell -p sops --run "sops secrets/secrets.yaml"`
2. Update `system/secrets.nix`: Add to `sops.secrets` and `sops.templates."secrets.env".content`
3. Rebuild: `nhs`

**Managed Secrets**:
- API Keys: NPM_TOKEN, GEMINI_API_KEY, OPENAI_API_KEY, ANTHROPIC_API_KEY, CIRCLECI_TOKEN
- Android: ANDROID_RELEASE_KEYSTORE_PASSWORD, ANDROID_RELEASE_KEY_PASSWORD, ANDROID_KEYSTORE_PASSWORD
- Production: APC_WSS_ADMIN_BEARER_TOKEN, APC_WSS_FIREBASE_ADMIN_CONFIG, APC_WSS_A3_PG_PASSWORD
- Backup: borg_passphrase (root-owned, mode 0400, for Borg backups)

**Generated Environment Variables**:
The secrets.env template includes both secrets and non-secret constants:
- Android aliases: ANDROID_RELEASE_KEY_ALIAS="release-key", ANDROID_KEYSTORE_ALIAS="Anova"
- Google KMS: APC_WSS_GOOGLE_KMS_A3_SECRET_KEYRING, APC_WSS_GOOGLE_KMS_A3_SECRET_KEY_NAME
- PostgreSQL: APC_WSS_A3_PG_HOST, APC_WSS_A3_PG_PORT, APC_WSS_A3_PG_USER, APC_WSS_A3_PG_DATABASE

**Security**:
- ✅ Commit: `secrets/secrets.yaml`, `.sops.yaml`
- ❌ Never commit: `~/.config/sops/age/keys.txt`, `secrets/secrets-template.yaml`
- Always back up your age private key securely
- Secrets only decrypted locally during system activation

**Troubleshooting**:
- Secrets not loading? Check `~/.config/secrets.env` exists, rebuild with `nhs`, start new bash session
- Can't decrypt? Verify age key exists and public key in `.sops.yaml` matches
- Rotate key: Generate new with `age-keygen`, update `.sops.yaml`, run `sops updatekeys secrets.yaml`

## Custom Packages

**Tiny4Linux** (pkgs/tiny4linux.nix):
- Linux controller for OBSBOT Tiny2 camera
- Version: 2.2.2 from github:OpenFoxes/Tiny4Linux
- Built from Rust source with GUI and CLI features
- Desktop entry created for easy access
- Launch: `tiny4linux-gui` or from application menu

## Terminal & Shell

**Tmux Configuration**:
- Auto-attach to "main" session on bash login
- Mouse support enabled
- Custom split keybindings: `h` (horizontal), `v` (vertical)
- Window management: `n` (new), `w` (kill window), `x` (kill pane)
- Pane movement with arrow keys
- Ctrl+K to clear console
- Ctrl+_ mapped to Shift-Tab
- Status bar enabled with session name

**Alacritty Terminal**:
- Theme: moonfly
- Background: pure black (#000000)

**Bash Configuration**:
- Sources ~/.alias if exists
- Auto-sources ~/.config/secrets.env
- Auto-attaches to tmux "main" session on login (unless already in tmux)
- Shell aliases: `ls`→`eza`, `cat`→`bat`, `top`→`btop`, `code`→`codium`, `c`→`claude`, `nano`→`micro`
- `nhs` alias: Full rebuild + auto-commit + push workflow

## Network & Remote Access

**SSH Configuration**:
- Macbook host: 192.168.0.232 (user: joemitz)

**OpenSSH Server**:
- Port: 22 (TCP)
- Password authentication: enabled
- Root login: allowed

**Tailscale VPN**:
- Enabled for secure remote access
- UDP port 41641 open in firewall

**NFS Client**:
- rpcbind enabled for NFS support
- TrueNAS Plex share auto-mounted at /mnt/truenas/plex (read-only)

**Wake-on-LAN**:
- Enabled on interface enp6s0

## Full System Impermanence

This system uses **full impermanence** - both root and home filesystems are wiped and restored to a clean state on every boot. This provides a truly stateless, reproducible system where only explicitly declared state persists.

**How it works**:
1. During boot, after devices are available but before root is mounted
2. The system mounts the Btrfs root volume
3. Recursively deletes all nested subvolumes under @ (root)
4. Deletes the @ subvolume itself
5. Creates a fresh @ subvolume from the @blank snapshot
6. Continues normal boot process

**What persists**:
- `/nix` - Mounted from @nix subvolume (Nix store, always persistent)
- `/persist-root` - Mounted from @persist-root subvolume, contains system state:
  - System state: logs, NetworkManager connections, Docker data, Bluetooth pairings
  - Service state: Tailscale, CUPS, SDDM, systemd timers
  - SSH host keys and machine-id
- `/persist-dotfiles` - Mounted from @persist-dotfiles subvolume, contains user configs:
  - Application configs: .config, .local, .ssh, .claude
  - Development caches: .gradle, .npm, .cargo, .android
  - Browser data: .mozilla, .cache
  - Application data: .zoom, .vscode-oss, .var (flatpak)
- `/persist-userfiles` - Mounted from @persist-userfiles subvolume, contains user data:
  - Projects: nixos-config, anova
  - User directories: Documents, Downloads, Pictures, Videos, Desktop
  - Android SDK, Postman collections

**What gets wiped on every boot**:
- Entire root filesystem (/) except /nix and persistence mounts
- Entire home directory (~) except explicitly persisted files/directories
- Any temporary files, system logs not in /persist-root
- Any user files not in /persist-dotfiles or /persist-userfiles

**Benefits**:
- Truly clean slate on every boot - no accumulated cruft anywhere
- Reproducible system and home state
- Forces explicit declaration of what should persist
- Makes it obvious what state is truly necessary
- Easy rollback from any issue - just reboot
- KDE Plasma settings, SSH keys, and dev tools persist correctly

**Impermanence Configuration**:
- Uses the impermanence NixOS module
- Three separate persistence points for organized state management
- hideMounts enabled to keep persistence mounts hidden from file browsers
- Directories and files explicitly listed for persistence in system/persistence.nix

## Backup System

**Borg Backup Configuration**:
- Service: `persist-backup` backs up all three persistence subvolumes to remote Borg repository
- Repository: ssh://borg@192.168.0.100:2222/backup/nixos-persist
- Encryption: repokey-blake2 with passphrase from sops secrets
- Compression: auto,lz4 for good balance of speed and size
- Schedule: Runs hourly
- SSH key: /home/joemitz/.ssh/id_ed25519_borg (auto-accept new hosts)

**Backup Retention**:
- Hourly: 2 backups
- Daily: 7 backups
- Weekly: 4 backups
- Monthly: 6 backups
- Yearly: 2 backups

**What's backed up**:
- `/persist-root` - System state (NetworkManager, Docker, SSH host keys, logs)
- `/persist-dotfiles` - User configs and application data
- `/persist-userfiles` - User documents and projects

**What's excluded from backups** (can be rebuilt):
- All .cache directories
- Build/download caches: .gradle, .npm, .cargo, .compose-cache
- Android AVDs and cache (can be recreated)
- KDE Baloo indexer cache (rebuilds automatically)
- Trash and logs
- node_modules (rebuilt from package.json)
- Android/iOS build artifacts (build, .gradle, Pods)

**What's NOT backed up** (doesn't need to be):
- / (root) - Wiped on every boot, fully reproducible from config
- /nix - Nix store is reproducible from configuration

**Recovery**:
To restore from backup after a catastrophic failure:
1. Reinstall NixOS with same subvolume structure (@, @nix, @blank, @persist-root, @persist-dotfiles, @persist-userfiles)
2. Restore all persist subvolumes from Borg: `borg extract ssh://borg@192.168.0.100:2222/backup/nixos-persist::archive-name`
3. Run `nhs` to rebuild system from configuration in /persist-userfiles/home/joemitz/nixos-config
