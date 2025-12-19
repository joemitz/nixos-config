# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a NixOS configuration repository using flakes and home-manager. The system is configured for user `joemitz` on hostname `nixos` running KDE Plasma 6 on x86_64-linux. Claude Code is installed via a flake input from `github:sadjow/claude-code-nix`.

## Core Architecture

**Flake Structure**:
- `flake.nix`: Main entry point defining inputs (nixpkgs, home-manager, claude-code) and outputs
- `configuration.nix`: System-level NixOS configuration (bootloader, networking, desktop environment, system packages)
- `home.nix`: User-level home-manager configuration (user packages, git config, bash/tmux settings)
- `hardware-configuration.nix`: Hardware-specific configuration (generated, not typically edited manually)
- `cachix/`: Binary cache configurations, including claude-code.cachix.org

**Key Design Decisions**:
- Uses `nixos-unstable` channel for latest packages
- home-manager integrated as a NixOS module (not standalone)
- Experimental features enabled: `nix-command` and `flakes`
- NH (Nix Helper) configured as modern replacement for nixos-rebuild
- Git hooks disabled globally (`core.hooksPath = "/dev/null"`)
- Auto-commits configuration changes after successful rebuilds via `nhs` alias

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

NH is configured in configuration.nix:141-149 with:
- Automatic weekly garbage collection
- Keeps last 5 generations and anything from last 4 days
- Flake path: `/home/joemitz/nixos-config`

The activation script at configuration.nix:153-155 ensures proper file ownership to allow NH to update flake.lock without permission errors.

## Configuration Layout

**System Configuration** (configuration.nix):
- Boot: systemd-boot with EFI
- Desktop: KDE Plasma 6 with SDDM
- Audio: PipeWire (replaces PulseAudio)
- Services: OpenSSH enabled on port 22
- NVMe mount at /mnt/nvme (Btrfs with subvol=@)
- Timezone: America/Los_Angeles

**User Configuration** (home.nix):
- Packages: claude-code, gh, tmux, vscodium, postman, zoom-us
- Git configured with useful aliases (co, st, br, hi, cp, lb, ma)
- Bash with tmux auto-attach on login
- Custom tmux keybindings (h/v for splits, Ctrl+K to clear)

## Git Workflow

Git is configured with several useful aliases defined in home.nix:41-54:
- `git co`: Quick commit (`git commit -m`)
- `git cp`: Commit and push in one command
- `git hi`: Pretty log with graph
- `git lb`: Show last 10 branch checkouts
- `git ma`: Show last 30 merge commits

Auto-setup-remote is enabled for pushing new branches.

## Important Notes

- System state version: 25.11 (do not change without reading documentation)
- Home state version: 25.11
- Unfree packages are allowed system-wide
- The configuration auto-commits successfully applied changes to track system generations
- All .nix files and flake.lock have ownership fixed on activation to allow NH updates
