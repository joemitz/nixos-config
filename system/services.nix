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

  # Grant Kopia the capability to read any file (for backing up system files)
  # This allows kopia-ui to backup /persist-root without running as root
  # Capability is automatically reapplied after each kopia update
  system.activationScripts.kopia-capabilities = ''
    # Find kopia binary by extracting path from kopia-ui wrapper script
    KOPIA_UI_WRAPPER=$(${pkgs.coreutils}/bin/readlink -f ${pkgs.kopia-ui}/bin/kopia-ui)
    KOPIA_BIN=$(${pkgs.gnugrep}/bin/grep -oP '/nix/store/[^/]+kopia-[0-9.]+/bin' "$KOPIA_UI_WRAPPER" | ${pkgs.coreutils}/bin/head -n1)/kopia

    if [ -n "$KOPIA_BIN" ] && [ -f "$KOPIA_BIN" ]; then
      ${pkgs.libcap}/bin/setcap cap_dac_read_search=+ep "$KOPIA_BIN" 2>/dev/null || true
      echo "Set read capabilities on $KOPIA_BIN"
    else
      echo "Warning: Could not find kopia binary for capability setting"
    fi
  '';

  # Nix settings
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    download-buffer-size = 536870912; # 512 MiB
    trusted-users = [ "root" "joemitz" ];
  };
}
