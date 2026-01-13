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
│   ├── snapper.nix             # Snapper snapshots configuration
│   └── borg.nix                # Borg backup configuration
├── home/
│   ├── index.nix               # Main entry point (imports all modules)
│   ├── packages.nix            # Home packages (apps, tools, custom packages)
│   ├── git.nix                 # Git configuration with aliases
│   ├── ssh.nix                 # SSH configuration
│   ├── direnv.nix              # Direnv with nix-direnv integration
│   ├── bash.nix                # Bash aliases, env vars, nhs alias
│   ├── tmux.nix                # Tmux configuration and keybindings
│   ├── alacritty.nix           # Terminal theme and colors
│   ├── firefox.nix             # Firefox browser
│   └── desktop-entries.nix     # XDG desktop entries (guvcview, tiny4linux)
├── cachix/
│   ├── default.nix            # Auto-imports all cachix configs
│   └── claude-code.nix        # Claude Code binary cache
├── secrets/
│   ├── secrets.yaml           # Encrypted secrets (committed)
│   └── secrets-template.yaml  # Template (not committed)
└── pkgs/
    └── tiny4linux.nix         # Custom OBSBOT Tiny2 camera package
```

**Flake Structure**:
- `flake.nix`: Main entry point defining inputs (nixpkgs stable, home-manager, claude-code, sops-nix, tiny4linux, impermanence) and outputs
- `system/index.nix`: Main system configuration entry point (imports all system modules)
- `system/*.nix`: Modular system configuration split by concern (boot, hardware, networking, desktop, users, secrets, services, persistence, snapper, borg)
- `home/index.nix`: Main home-manager entry point (imports all home modules)
- `home/*.nix`: Modular home configuration split by program (packages, git, ssh, direnv, bash, tmux, alacritty, firefox, desktop-entries)
- `system/hardware-configuration.nix`: Hardware-specific configuration with Btrfs subvolumes (generated, not typically edited manually)
- `pkgs/tiny4linux.nix`: Custom package for OBSBOT Tiny2 camera controller
- `cachix/`: Binary cache configurations (claude-code). Auto-import system uses cleanup of unused parameters for code hygiene.
- `secrets/`: Encrypted secrets managed by sops-nix

**Key Design Decisions**:
- Uses `nixos-25.11` stable channel with regular updates to nixpkgs inputs
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
- Binary caches configured: cache.nixos.org, claude-code.cachix.org

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
2. Runs `deadnix -e .` to remove unused code (arguments, variables, let bindings)
3. Runs `statix fix .` to fix style issues (empty patterns, manual inherits, etc.)
4. Runs `nh os switch`
5. On success: invokes Claude Haiku to analyze git diff, update CLAUDE.md, and generate commit message
6. Reads commit message from temporary file in config directory
7. Cleans up temporary commit message file
8. Stages all changes with `git add -A`
9. Commits changes with generation number and generated message
10. Pushes to git remote
11. Returns to original directory

**Stage for next boot with auto-commit and push** (use the `nhb` bash alias):
```bash
nhb
```
This alias:
1. Switches to the config directory
2. Runs `deadnix -e .` to remove unused code (arguments, variables, let bindings)
3. Runs `statix fix .` to fix style issues (empty patterns, manual inherits, etc.)
4. Runs `nh os boot` (stages configuration for next boot, doesn't switch immediately)
5. On success: auto-commits changes with generation number and timestamp
6. Pushes to git remote
7. Returns to original directory

**IMPORTANT: Claude Code must NEVER run nhs or nhb automatically**:
- Claude should make configuration changes and then stop
- The user will run `nhs` or `nhb` manually to rebuild and commit
- Do NOT attempt to run `bash -ic "nhs"`, `bash -ic "nhb"`, or any rebuild commands automatically
- Only run rebuild commands if explicitly requested by the user

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
- **boot.nix**: systemd-boot with EFI, kernel 6.6 LTS (pkgs.linuxPackages_6_6), root rollback on boot
- **hardware.nix**: AMD GPU with amdgpu driver early loading, hardware acceleration, Bluetooth with power-on-boot enabled, firmware updates, NFS mount (TrueNAS at 192.168.0.55)
- **desktop.nix**: KDE Plasma 6 with SDDM (Wayland enabled, breeze theme, Opal wallpaper background), PipeWire audio, printing, kde-rounded-corners
- **networking.nix**: NetworkManager, Wake-on-LAN on enp6s0, Tailscale VPN, firewall, OpenSSH (port 22, password auth enabled)
- **users.nix**: User accounts (joemitz with groups: networkmanager, wheel, docker, adbusers, kvm; root), timezone (America/Los_Angeles), locale, polkit, passwordless sudo
- **secrets.nix**: Complete sops-nix configuration for encrypted secrets management
- **services.nix**: Docker, ADB for Android, NFS client, nix-ld (for Android SDK tools), NH (Nix Helper), Nix settings (experimental features, trusted-users for signing and remote builds)
- **persistence.nix**: Impermanence configuration - root and home wipe on boot, state persisted to three subvolumes
- **snapper.nix**: Snapper configuration for Btrfs snapshots of persistence subvolumes (joemitz allowed user)
- **borg.nix**: Borg hourly backups to remote server (192.168.0.100) with desktop notifications, automatic retries, excludes Snapper snapshots and Docker images
- **Filesystem**: Btrfs with subvolumes (@, @nix, @blank, @persist-root, @persist-dotfiles, @persist-userfiles) and zstd compression

**User Configuration** (modular structure in home/):
- **packages.nix**: All user packages - CLI tools (claude-code, gh, jq, awscli2, awslogs, devbox, nodejs_24, btop, eza), Nix tools (nixd, nixpkgs-fmt, nixf, statix, deadnix, sops), development apps (vscodium, postman, android-studio, android-tools, jdk11), applications (zoom-us, tidal-hifi, vlc, gimp, guvcview, remmina), custom packages (tiny4linux). Module header cleaned to include only required parameters (removed unused `config`). Note: tmux enabled via programs.tmux in tmux.nix, not listed here
- **git.nix**: Git with gitFull package, user config, useful aliases (co, st, br, hi, lb, ma, type, dump, pu, ad, ch, cp), LFS support, libsecret credential helper (KDE Wallet)
- **ssh.nix**: SSH configuration with macbook host (192.168.0.232)
- **direnv.nix**: direnv with bash integration and nix-direnv support
- **bash.nix**: Shell aliases (ls→eza, top→btop, code→codium, c→claude, zzz→suspend), nhs alias (rebuild+commit+push), nhb alias (stage for boot+commit+push), session variables (NODE_ENV, DEVICE_IP, HUSKY, ANDROID_HOME), Android SDK paths, secrets sourcing, tmux auto-attach
- **tmux.nix**: Tmux with custom keybindings (h/v for splits, n for new window, w/x for kill, Ctrl+K to clear, Ctrl+_ for Shift-Tab), mouse support, status bar
- **alacritty.nix**: Terminal with moonfly theme and pure black background (#000000)
- **firefox.nix**: Firefox browser enabled
- **nixd.nix**: Nixd language server configuration with nixpkgs, NixOS, and home-manager IDE features (autocomplete, diagnostics, go-to-definition, formatting)
- **desktop-entries.nix**: XDG desktop entries for guvcview (with -z flag) and tiny4linux-gui

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
- `git cp`: Commit with message and push (`git commit -m "$1" && git push`)
- `git lb`: Show last 10 branch checkouts with colors
- `git ma`: Show last 30 merge commits with colors

Auto-setup-remote is enabled for pushing new branches. Git LFS is configured. Credential helper uses libsecret (KDE Wallet).

## Important Notes

- System state version: 25.11 (do not change without reading documentation)
- Home state version: 25.11
- Unfree packages are allowed system-wide
- The configuration auto-commits successfully applied changes to track system generations
- All .nix files and flake.lock have ownership fixed on activation to allow NH updates
- Using 6.6 LTS kernel to avoid AMD GPU bug in 6.12.10+ (see https://bbs.archlinux.org/viewtopic.php?id=303556)
- AMD GPU driver loaded early in initrd for proper display detection before SDDM
- KVM module (kvm-amd) enabled for virtualization
- AMD CPU microcode updates enabled
- Module function parameters: Modules using no parameters use `_:` instead of `{ ... }:` for clarity. Only explicitly required parameters are included in module headers.

## Hardware & Kernel

**AMD GPU Configuration**:
- Driver: amdgpu (loaded early in boot via initrd)
- Hardware acceleration enabled (32-bit support included)
- Video driver explicitly set to "amdgpu"

**Kernel**: 6.6 LTS (linuxPackages_6_6) to avoid stability issues with newer kernels on AMD GPUs

**Filesystem**:
- Root filesystem: Btrfs with subvolumes (@, @nix, @blank, @persist-root, @persist-dotfiles, @persist-userfiles)
- Mount options: compress=zstd, noatime, space_cache=v2 (on root), space_cache (on /nix)
- Root (@) subvolume: Rolls back to pristine @blank snapshot on every boot (stateless root)
- All persistence subvolumes: neededForBoot = true
- /persist-root: System state (NetworkManager, Docker, SSH keys, logs, etc.)
- /persist-dotfiles: User configs and application data (.config, .local, .ssh, .claude, etc.)
- /persist-userfiles: User documents and projects (nixos-config, anova, Documents, Downloads, etc.)
- All home files not explicitly persisted are wiped on reboot (stateless home)
- TrueNAS NFS share mounted at /mnt/truenas/plex (read-only)
- OpenSUSE home subvolume mounted at /mnt/opensuse (read-only, for accessing files from OpenSUSE installation)

**Snapper Snapshots**:
- Configured for persist-root, persist-dotfiles, and persist-userfiles
- Only snapshots persistent data (root and home are stateless, no point in snapshotting)
- User joemitz is allowed to manage snapshots
- Timeline creation and cleanup enabled for all configs
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
- nix-ld enabled for running Android SDK dynamically linked executables (AAPT2, CMake, Ninja, NDK tools)
- Environment variables configured in home.nix:
  - ANDROID_HOME: $HOME/Android/Sdk
  - PATH includes emulator and platform-tools
  - ANDROID_RELEASE_KEY_ALIAS="release-key"
  - ANDROID_KEYSTORE_ALIAS="Anova"

**Docker**: Enabled with user in docker group

**Node.js**: Version 24 installed

**Nix Development Tools**:
- **nixd**: Nix language server providing IDE features (autocomplete, diagnostics, go-to-definition, formatting)
  - Configuration: `~/.config/nixd/config.json` (managed by home-manager)
  - Configured to use flake at `/home/joemitz/nixos-config`
  - Provides completion for nixpkgs, NixOS options, and home-manager options
- **deadnix**: Auto-fix tool for removing unused Nix code
  - Automatically runs via `deadnix -e .` when using `nhs` or `nhb` aliases
  - Removes: unused lambda arguments, unused let bindings, unused variables
  - Manual usage: `deadnix /path/to/dir` (check only), `deadnix -e /path/to/dir` (auto-fix)
  - Options: `-l` (skip lambda args), `-_` (skip underscore-prefixed bindings)
- **statix**: Linter with auto-fix for Nix code style issues
  - Automatically runs via `statix fix .` when using `nhs` or `nhb` aliases (after deadnix)
  - Fixes: empty patterns (converts `{ ... }:` to `_:`), redundant bindings, empty let blocks, manual inherits, and other style issues
  - Manual usage: `statix check /path/to/dir` (check only), `statix fix /path/to/dir` (auto-fix)
  - Dry-run: `statix fix --dry-run /path/to/dir` (preview changes without modifying files)
  - List all checks: `statix list`
- **nixf-tidy**: Command-line linter for Nix files (diagnostic only, no auto-fix)
  - Checks for unused arguments, unnecessary `rec` keywords, and other code issues
  - Outputs JSON array of diagnostics
  - Usage: `nixf-tidy --variable-lookup < file.nix`
  - Scan all config files: `for file in /home/joemitz/nixos-config/{system,home}/*.nix /home/joemitz/nixos-config/flake.nix /home/joemitz/nixos-config/pkgs/*.nix /home/joemitz/nixos-config/cachix/*.nix; do if [ -f "$file" ]; then result=$(nixf-tidy --variable-lookup < "$file" 2>&1); if [ "$result" != "[]" ]; then echo "=== $file ==="; echo "$result"; fi; fi; done`
  - Empty output `[]` means no errors found
- **nixpkgs-fmt**: Nix code formatter used by nixd

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
- Custom magenta colors (#d79600 normal, #ffbf5f bright)

**Bash Configuration**:
- Sources ~/.alias if exists
- Auto-sources ~/.config/secrets.env
- Auto-attaches to tmux "main" session on login (unless already in tmux)
- Shell aliases: `ls`→`eza`, `top`→`btop`, `code`→`codium`, `c`→`claude`, `nano`→`micro`, `zzz`→`systemctl suspend`
- `nhs` alias: Full rebuild + auto-commit + push workflow (invokes Claude Haiku to generate commit message and update CLAUDE.md with important changes only)
- `nhb` alias: Stage for boot + auto-commit + push workflow

## Network & Remote Access

**SSH Configuration**:
- Macbook host: 192.168.0.232 (user: joemitz)

**OpenSSH Server**:
- Port: 22 (TCP)
- Password authentication: enabled

**Tailscale VPN**:
- Enabled for secure remote access
- UDP port 41641 open in firewall

**NFS Client**:
- rpcbind enabled for NFS support
- TrueNAS Plex share (192.168.0.55:/mnt/main-pool/plex) auto-mounted at /mnt/truenas/plex (read-only)

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
  - Application configs: .config, .local, .ssh, .claude, .aws
  - Development caches: .gradle, .npm, .cargo, .compose-cache, .android
  - Development settings: .react-native-cli, .java
  - Browser data: .mozilla, .cache
  - Application data: .zoom, .vscode-oss, .var (flatpak)
  - Visual customization: .icons, .pki
- `/persist-userfiles` - Mounted from @persist-userfiles subvolume, contains user data:
  - Projects: nixos-config, anova
  - User directories: Documents, Downloads, Pictures, Videos, Music, Desktop
  - Development tools: Android SDK, Postman collections
  - Miscellaneous: misc directory
  - Root-level CLAUDE.md file

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
- Schedule: Runs hourly, but only allows backups within first 5 minutes of each hour (prevents catch-up backups after suspend/wake)
- SSH key: /home/joemitz/.ssh/id_ed25519_borg (auto-accept new hosts)
- Desktop notifications: Success (low urgency, 5s) and failure (critical urgency) notifications via libnotify
- Network dependencies: Waits for network-online.target and NetworkManager-wait-online.service
- Automatic retry: 3 total attempts (1 initial + 2 retries) with 2 minute delay between attempts, restart mode set to direct (OnFailure only triggers on final failure)
- Time-check wrapper: `preStart` script ensures backups only run within first 5 minutes of the hour (e.g., waking at 12:52 will skip the backup until 1:00-1:05)

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
- Trash and logs (.local/share/Trash, .zoom/logs)
- node_modules (rebuilt from package.json)
- Android/iOS build artifacts (build, .gradle, Pods)
- Build output directories (dist)
- Test coverage reports (coverage)
- Docker images (can be rebuilt)
- Snapper snapshots (redundant with Borg versioning, saves ~139GB)

**What's NOT backed up** (doesn't need to be):
- / (root) - Wiped on every boot, fully reproducible from config
- /nix - Nix store is reproducible from configuration

**Recovery**:
To restore from backup after a catastrophic failure:
1. Reinstall NixOS with same subvolume structure (@, @nix, @blank, @persist-root, @persist-dotfiles, @persist-userfiles)
2. Restore all persist subvolumes from Borg: `borg extract ssh://borg@192.168.0.100:2222/backup/nixos-persist::archive-name`
3. Run `nhs` to rebuild system from configuration in /persist-userfiles/home/joemitz/nixos-config
