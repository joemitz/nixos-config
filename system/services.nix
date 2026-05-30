{ pkgs, ... }:

{
  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Enable nix-ld for running dynamically linked executables (Android SDK tools, Electron)
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      glib gtk3 gdk-pixbuf dbus
      nss nspr
      atk at-spi2-atk at-spi2-core
      cups libdrm
      cairo pango
      xorg.libX11 xorg.libXcomposite xorg.libXdamage xorg.libXext
      xorg.libXfixes xorg.libXrandr xorg.libxcb
      libxkbcommon expat
      alsa-lib udev
      mesa libgbm
    ];
  };

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

  # Power on Bluetooth adapter at boot.
  # The CSR clone dongle (0a12:0001) times out during HCI_OP_RESET on init,
  # leaving the adapter DOWN when bluetoothd's AutoEnable runs. A short delay
  # lets the adapter settle before we explicitly power it on.
  systemd.services.bluetooth-autopower = {
    description = "Power on Bluetooth adapter after boot";
    after = [ "bluetooth.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStartPre = "${pkgs.coreutils}/bin/sleep 5";
      ExecStart = "${pkgs.bluez}/bin/bluetoothctl power on";
      RemainAfterExit = true;
    };
  };

  # Nix settings
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    download-buffer-size = 536870912; # 512 MiB
    trusted-users = [ "root" "joemitz" ];
  };
}
