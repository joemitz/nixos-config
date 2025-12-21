# Impermanence Configuration
# Root filesystem is ephemeral - wiped on every boot
# Only explicitly declared paths persist in /persist subvolume

{ config, pkgs, lib, ... }:

{
  # Import impermanence module
  imports = [
    "${builtins.fetchTarball "https://github.com/nix-community/impermanence/archive/master.tar.gz"}/nixos.nix"
  ];

  # Configure what persists in /persist subvolume
  environment.persistence."/persist" = {
    # Persist these directories
    directories = [
      # NixOS system state
      "/var/lib/nixos"          # UID/GID mappings, etc.
      "/var/lib/systemd"        # Systemd state (timers, coredumps, etc.)

      # Logs (helpful for debugging)
      "/var/log"                # System logs

      # Network configuration
      "/etc/NetworkManager/system-connections"  # WiFi passwords, etc.

      # Optional but useful
      # "/var/cache"            # System cache (uncomment if needed)
      # "/var/lib/bluetooth"    # Bluetooth pairings (uncomment if you use BT)
    ];

    # Persist these individual files
    files = [
      # System identity
      "/etc/machine-id"         # Stable machine identifier

      # SSH host keys (so host identity doesn't change each boot)
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
      "/etc/ssh/ssh_host_rsa_key"
      "/etc/ssh/ssh_host_rsa_key.pub"
    ];

    # Persist root user's home directory items
    # Only needed if root needs persistent data
    users.root = {
      home = "/root";
      directories = [
        # ".cache"              # Nix eval cache (uncomment if desired)
      ];
      files = [
        # Add any root-specific files here
      ];
    };
  };

  # Optional: Automatically create /persist directory structure
  # This ensures directories exist before persistence tries to bind-mount them
  system.activationScripts.createPersistDirs = lib.mkAfter ''
    mkdir -p /persist/var/lib/nixos
    mkdir -p /persist/var/lib/systemd
    mkdir -p /persist/var/log
    mkdir -p /persist/etc/NetworkManager/system-connections
    mkdir -p /persist/etc/ssh
  '';
}
