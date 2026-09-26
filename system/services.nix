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

  # Disable 3-finger tap-to-middle-click on the Magic Trackpad, which triggers
  # X11/Wayland primary-selection paste in every app (including Firefox).
  # libinput's tap-to-click only supports a global on/off plus an LRM/LMR
  # finger-to-button map swap (no per-finger-count disable), so instead this
  # removes BTN_MIDDLE from the device's reported event codes entirely,
  # below KWin and every toolkit. 1 and 2 finger tap (left/right click) are
  # unaffected. Trade-off: middle-click-to-open-link-in-new-tab no longer
  # works from the trackpad either (a real mouse's middle button still does).
  environment.etc."libinput/local-overrides.quirks".text = ''
    [Magic Trackpad No Middle Tap]
    MatchVendor=0x05AC
    MatchProduct=0x0265
    MatchUdevType=touchpad
    AttrEventCode=-BTN_MIDDLE
  '';

  # Grant the "input" group access to /dev/uinput so dotool (used by Handy for
  # dictation) can inject keystrokes on Wayland/KWin, which lacks the
  # virtual-keyboard protocol wtype depends on.
  boot.kernelModules = [ "uinput" ];
  services.udev.extraRules = ''
    KERNEL=="uinput", SUBSYSTEM=="misc", TAG+="uaccess", OPTIONS+="static_node=uinput", GROUP="input", MODE="0660"
  '';

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
      enable = true;  # Auto-clean weekly, keep last 30 days (prevents /boot from filling up)
      dates = "weekly";
      extraArgs = "--keep-since 30d";
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
