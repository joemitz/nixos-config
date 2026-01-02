# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a NixOS configuration repository using flakes and home-manager. The system is configured for user `joemitz` on hostname `nixos` running KDE Plasma 6 on x86_64-linux (AMD CPU + GPU). Claude Code is installed via a flake input from `github:sadjow/claude-code-nix`.

## Core Architecture

**Flake Structure**:
- `flake.nix`: Main entry point defining inputs (nixpkgs stable, home-manager, claude-code, sops-nix, tiny4linux) and outputs
- `configuration.nix`: System-level NixOS configuration (bootloader, networking, desktop environment, system services)
- `home.nix`: User-level home-manager configuration (user packages, git config, bash/tmux/alacritty settings)
- `hardware-configuration.nix`: Hardware-specific configuration with Btrfs subvolumes (generated, not typically edited manually)
- `pkgs/tiny4linux.nix`: Custom package for OBSBOT Tiny2 camera controller
- `cachix/`: Binary cache configurations

**Key Design Decisions**:
- Uses `nixos-25.11` stable channel
- home-manager integrated as a NixOS module (not standalone)
- Experimental features enabled: `nix-command` and `flakes`
- NH (Nix Helper) configured as modern replacement for nixos-rebuild
- Git hooks disabled globally (`core.hooksPath = "/dev/null"`)
- Auto-commits configuration changes after successful rebuilds via `nhs` alias
- Btrfs filesystem with compression (zstd) and snapshots via Snapper
- LTS kernel to avoid AMD GPU bugs in newer kernels

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

NH is configured in configuration.nix:229-237 with:
- Automatic weekly garbage collection
- Keeps last 5 generations and anything from last 4 days
- Flake path: `/home/joemitz/nixos-config`

The activation script at configuration.nix:241-243 ensures proper file ownership to allow NH to update flake.lock without permission errors.

## Configuration Layout

**System Configuration** (configuration.nix):
- Boot: systemd-boot with EFI, LTS kernel (pkgs.linuxPackages)
- Hardware: AMD GPU with amdgpu driver early loading, hardware acceleration, Bluetooth
- Desktop: KDE Plasma 6 with SDDM
- Audio: PipeWire (replaces PulseAudio)
- Networking: NetworkManager, Wake-on-LAN on enp6s0, Tailscale VPN
- Services: OpenSSH (port 22), fwupd firmware updates, Snapper for Btrfs snapshots
- Development: Docker, ADB for Android
- Security: Polkit enabled, sudo without password for wheel group
- User groups: networkmanager, wheel, docker, adbusers, kvm
- Filesystem: Btrfs with subvolumes (@, @home, @nix) and zstd compression
- NVMe mount at /mnt/nvme (Btrfs with subvol=@)
- Timezone: America/Los_Angeles

**User Configuration** (home.nix):
- CLI Tools: claude-code, gh, jq, tmux, patchelf, devbox, nodejs_24
- Development: vscodium, postman, android-studio, android-tools
- Applications: zoom-us, firefox, tidal-hifi, vlc, guvcview, remmina, vorta (backup)
- Custom Packages: tiny4linux (OBSBOT Tiny2 camera controller)
- Git configured with useful aliases (co, st, br, hi, cp, lb, ma, type, dump, pu, ad, ch)
- SSH with macbook host configuration
- Bash with tmux auto-attach, secrets sourcing, Android SDK paths, nhs alias
- Tmux with custom keybindings (h/v for splits, n for new window, Ctrl+K to clear)
- Alacritty terminal with campbell theme and black background
- direnv with nix-direnv integration

## Git Workflow

Git is configured with several useful aliases defined in home.nix:53-66:
- `git co`: Quick commit (`git commit -m`)
- `git st`: Status
- `git br`: Branch
- `git hi`: Pretty log with graph and colors
- `git type`: Show object type (`cat-file -t`)
- `git dump`: Show object content (`cat-file -p`)
- `git pu`: Push
- `git ad`: Add
- `git ch`: Checkout
- `git cp`: Commit and push in one command
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
- Root filesystem: Btrfs with subvolumes (@, @home, @nix)
- Mount options: compress=zstd, noatime, space_cache=v2
- Additional NVMe drive mounted at /mnt/nvme

**Snapper Snapshots**:
- Configured for both / (root) and /home
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

**WebStorm**: PATH includes /opt/WebStorm-243.26053.12/bin

**Additional Environment Variables** (home.nix:119-125):
- NODE_ENV=development
- DEVICE_IP=192.168.0.249
- HUSKY=0 (disables git hooks)

## Secrets Management

This configuration uses [sops-nix](https://github.com/Mic92/sops-nix) to manage secrets securely.

**Files**:
- `secrets.yaml` - Encrypted secrets (safe to commit to git)
- `.sops.yaml` - sops configuration (safe to commit)
- `~/.config/sops/age/keys.txt` - Your age private key (NEVER commit! Back this up securely!)
- `~/.config/secrets.env` - Generated file sourced by bash (auto-created on rebuild)

**How It Works**:
1. Secrets stored encrypted in `secrets.yaml` using age encryption
2. On system activation, sops-nix decrypts and creates `~/.config/secrets.env`
3. Bash automatically sources this file, making secrets available as environment variables

**Editing Secrets**:
```bash
nix-shell -p sops --run "sops secrets.yaml"
```

**Adding New Secrets**:
1. Edit encrypted file: `nix-shell -p sops --run "sops secrets.yaml"`
2. Update `configuration.nix`: Add to `sops.secrets` and `sops.templates."secrets.env".content`
3. Rebuild: `nhs`

**Managed Secrets** (configuration.nix:123-135):
- API Keys: NPM_TOKEN, GEMINI_API_KEY, OPENAI_API_KEY, ANTHROPIC_API_KEY, CIRCLECI_TOKEN
- Android: ANDROID_RELEASE_KEYSTORE_PASSWORD, ANDROID_RELEASE_KEY_PASSWORD, ANDROID_KEYSTORE_PASSWORD
- Production: APC_WSS_ADMIN_BEARER_TOKEN, APC_WSS_FIREBASE_ADMIN_CONFIG, APC_WSS_A3_PG_PASSWORD

**Generated Environment Variables** (configuration.nix:141-161):
The secrets.env template includes both secrets and non-secret constants:
- Android aliases: ANDROID_RELEASE_KEY_ALIAS="release-key", ANDROID_KEYSTORE_ALIAS="Anova"
- Google KMS: APC_WSS_GOOGLE_KMS_A3_SECRET_KEYRING, APC_WSS_GOOGLE_KMS_A3_SECRET_KEY_NAME
- PostgreSQL: APC_WSS_A3_PG_HOST, APC_WSS_A3_PG_PORT, APC_WSS_A3_PG_USER, APC_WSS_A3_PG_DATABASE

**Security**:
- ✅ Commit: `secrets.yaml`, `.sops.yaml`
- ❌ Never commit: `~/.config/sops/age/keys.txt`, `secrets-template.yaml`
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

**Tmux Configuration** (home.nix:151-187):
- Auto-attach to "main" session on bash login
- Mouse support enabled
- Custom split keybindings: `h` (horizontal), `v` (vertical)
- Window management: `n` (new), `w` (kill window), `x` (kill pane)
- Pane movement with arrow keys
- Ctrl+K to clear console
- Ctrl+_ mapped to Shift-Tab
- Status bar enabled with session name

**Alacritty Terminal** (home.nix:189-195):
- Theme: campbell
- Background: pure black (#000000)

**Bash Configuration** (home.nix:89-149):
- Sources ~/.alias if exists
- Auto-sources ~/.config/secrets.env
- Auto-attaches to tmux "main" session on login (unless already in tmux)
- Custom aliases: `code` → `codium`, `c` → `claude`, `nhs` → full rebuild+commit+push

## Network & Remote Access

**SSH Configuration** (home.nix:70-79):
- Macbook host: 192.168.0.232 (user: joemitz)

**OpenSSH Server** (configuration.nix:189-195):
- Port: 22 (TCP)
- Password authentication: enabled
- Root login: disabled

**Tailscale VPN** (configuration.nix:198):
- Enabled for secure remote access
- UDP port 41641 open in firewall

**Wake-on-LAN** (configuration.nix:47):
- Enabled on interface enp6s0
