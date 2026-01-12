{ pkgs, ... }:

{
  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Enable ADB for Android development
  programs.adb.enable = true;

  # Enable nix-ld for running dynamically linked executables (Android SDK tools)
  programs.nix-ld.enable = true;

  # Enable NFS client support
  services.rpcbind.enable = true;

  # Enable Docker
  virtualisation.docker.enable = true;

  # NH (Nix Helper) - modern replacement for nixos-rebuild
  programs.nh = {
    enable = true;
    flake = "/home/joemitz/nixos-config";
    clean = {
      enable = true;
      dates = "weekly";
      extraArgs = "--keep 10 --keep-since 10d";
    };
  };

  # Fix ownership of NixOS configuration files
  # Ensures nh can update flake.lock without permission errors
  system.activationScripts.fix-nixos-config-permissions = ''
    chown -R joemitz:users /home/joemitz/nixos-config/*.nix /home/joemitz/nixos-config/flake.lock 2>/dev/null || true
  '';

  # Grant Kopia UI the capability to read any file (for backing up system files)
  # This allows kopia-ui to backup /persist-root without running as root
  # Capability must be reapplied after each kopia-ui update
  system.activationScripts.kopia-capabilities = ''
    KOPIA_BIN=$(find /nix/store -path "*/kopia-ui-*/libexec/kopia-ui/resources/server/kopia" 2>/dev/null | head -n1)
    if [ -n "$KOPIA_BIN" ] && [ -f "$KOPIA_BIN" ]; then
      ${pkgs.libcap}/bin/setcap cap_dac_read_search=+ep "$KOPIA_BIN" 2>/dev/null || true
      echo "Set capabilities on $KOPIA_BIN"
    fi
  '';

  # Nix settings
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    download-buffer-size = 536870912; # 512 MiB
    trusted-users = [ "root" "joemitz" ];
  };
}
