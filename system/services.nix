_:

{
  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Enable ADB for Android development
  programs.adb.enable = true;

  # Enable nix-ld for running dynamically linked executables (Android SDK tools)
  programs.nix-ld.enable = true;

  # Enable 1Password CLI and GUI
  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    # Allow unlocking with system password (requires polkit)
    polkitPolicyOwners = [ "joemitz" ];
  };

  # Enable NFS client support
  services.rpcbind.enable = true;

  # Enable Docker
  virtualisation.docker.enable = true;

  # Disable OpenSUSE swap auto-discovery (by UUID, not device name)
  # NixOS uses nvme0n1p3 for swap; prevent systemd from auto-activating OpenSUSE swap
  # Using UUID ensures mask works even if device name changes (sda→sdb)
  systemd.units."dev-disk-by\\x2duuid-549e5677\\x2ddc32\\x2d4b89\\x2d81c7\\x2d1c83b3eed996.swap".enable = false;

  # NH (Nix Helper) - modern replacement for nixos-rebuild
  programs.nh = {
    enable = true;
    flake = "/home/joemitz/nixos-config";
    clean = {
      enable = false;  # Disabled - run manually with: nix-collect-garbage -d
      dates = "weekly";
      extraArgs = "--keep 10 --keep-since 10d";
    };
  };

  # Fix ownership of NixOS configuration files
  # Ensures nh can update flake.lock without permission errors
  system.activationScripts.fix-nixos-config-permissions = ''
    chown -R joemitz:users /home/joemitz/nixos-config/*.nix /home/joemitz/nixos-config/flake.lock 2>/dev/null || true
  '';

  # Unload ShapeCorners (kde-rounded-corners) before suspend and reload on resume.
  # KWin crashes on wake from sleep because the AMD GPU resets its OpenGL context and
  # ShapeCorners tries to render with stale GL state. Fixed in Plasma 6.6 (KWin MR !8677);
  # remove this when nixos-25.11 upgrades to Plasma 6.6 (expected with NixOS 26.05).
  powerManagement.powerDownCommands = ''
    runuser -l joemitz -c \
      "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus \
       dbus-send --session --type=method_call \
       --dest=org.kde.KWin /Effects \
       org.kde.kwin.Effects.unloadEffect string:kwin4_effect_shapecorners" || true
  '';
  powerManagement.resumeCommands = ''
    sleep 2
    runuser -l joemitz -c \
      "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus \
       dbus-send --session --type=method_call \
       --dest=org.kde.KWin /Effects \
       org.kde.kwin.Effects.loadEffect string:kwin4_effect_shapecorners" || true
  '';

  # Nix settings
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    download-buffer-size = 536870912; # 512 MiB
    trusted-users = [ "root" "joemitz" ];
  };
}
