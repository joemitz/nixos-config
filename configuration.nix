# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Use LTS kernel to avoid AMD GPU bug in kernel 6.12.10+
  # See: https://bbs.archlinux.org/viewtopic.php?id=303556
  boot.kernelPackages = pkgs.linuxPackages;

  # Load AMD GPU driver early in boot (fixes display detection before SDDM starts)
  boot.initrd.kernelModules = [ "amdgpu" ];

  # Root impermanence: Rollback root subvolume to pristine state on boot
  boot.initrd.postDeviceCommands = pkgs.lib.mkAfter ''
    mkdir -p /mnt

    # Mount the btrfs root to /mnt for subvolume manipulation
    mount -t btrfs -o subvolid=5 /dev/disk/by-uuid/a895216b-d275-480c-9b78-04c6a00df14a /mnt

    # Delete all nested subvolumes recursively before removing root
    # Keep looping until no nested subvolumes remain
    while btrfs subvolume list -o /mnt/@ | grep -q .; do
      btrfs subvolume list -o /mnt/@ |
      cut -f9 -d' ' |
      while read subvolume; do
        echo "deleting /$subvolume subvolume..."
        btrfs subvolume delete "/mnt/$subvolume" || true
      done
    done

    echo "deleting /@ subvolume..."
    btrfs subvolume delete /mnt/@

    echo "restoring blank /@ subvolume..."
    btrfs subvolume snapshot /mnt/@root-blank /mnt/@

    # Unmount and continue boot process
    umount /mnt
  '';

  # AMD GPU hardware acceleration
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Explicitly set AMD GPU as video driver
  services.xserver.videoDrivers = [ "amdgpu" ];

  # Enable Bluetooth (built-in and USB dongles)
  hardware.bluetooth.enable = true;

  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Enable Wake-on-LAN for enp6s0
  networking.interfaces.enp6s0.wakeOnLan.enable = true;

  # Set your time zone.
  time.timeZone = "America/Los_Angeles";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Enable the X11 windowing system.
  # You can disable this if you're only using the Wayland session.
  services.xserver.enable = true;

  # Enable the KDE Plasma Desktop Environment.
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable firmware updates
  services.fwupd.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  users.users.joemitz = {
    isNormalUser = true;
    description = "joemitz";
    extraGroups = [ "networkmanager" "wheel" "docker" "adbusers" "kvm" ];
    hashedPassword = "$6$cdmF4NEMLVzS4BDv$aK9lR1juxe512iK4SWVEFjailBjp96HThTA2zQkMRqOgThGISKIyA9x72Koa1qoVJ8VxbbHBZlni69BA9ZFKd/";
  };

  users.users.root = {
    hashedPassword = "$y$j9T$y2GlvoUIQM86.G9oHU4/P1$ig7BJtev.mK1LqGt73cNRURiqVsHlwViKS52WjuNnU/";
  };

  # sops-nix secrets management
  sops = {
    defaultSopsFile = ./secrets.yaml;
    age.keyFile = "/home/joemitz/.config/sops/age/keys.txt";

    # Define secrets and their output paths
    secrets = {
      "npm_token" = { owner = "joemitz"; };
      "gemini_api_key" = { owner = "joemitz"; };
      "openai_api_key" = { owner = "joemitz"; };
      "anthropic_api_key" = { owner = "joemitz"; };
      "circleci_token" = { owner = "joemitz"; };
      "android_release_keystore_password" = { owner = "joemitz"; };
      "android_release_key_password" = { owner = "joemitz"; };
      "android_keystore_password" = { owner = "joemitz"; };
      "apc_wss_admin_bearer_token" = { owner = "joemitz"; };
      "apc_wss_firebase_admin_config" = { owner = "joemitz"; };
      "apc_wss_a3_pg_password" = { owner = "joemitz"; };
    };

    # Create a templated secrets.env file for bash to source
    templates."secrets.env" = {
      owner = "joemitz";
      path = "/home/joemitz/.config/secrets.env";
      content = ''
        export NPM_TOKEN="${config.sops.placeholder.npm_token}"
        export GEMINI_API_KEY="${config.sops.placeholder.gemini_api_key}"
        export OPENAI_API_KEY="${config.sops.placeholder.openai_api_key}"
        export ANTHROPIC_API_KEY="${config.sops.placeholder.anthropic_api_key}"
        export CIRCLECI_TOKEN="${config.sops.placeholder.circleci_token}"
        export ANDROID_RELEASE_KEYSTORE_PASSWORD="${config.sops.placeholder.android_release_keystore_password}"
        export ANDROID_RELEASE_KEY_PASSWORD="${config.sops.placeholder.android_release_key_password}"
        export ANDROID_RELEASE_KEY_ALIAS="release-key"
        export ANDROID_KEYSTORE_ALIAS="Anova"
        export ANDROID_KEYSTORE_PASSWORD="${config.sops.placeholder.android_keystore_password}"
        export APC_WSS_ADMIN_BEARER_TOKEN="${config.sops.placeholder.apc_wss_admin_bearer_token}"
        export APC_WSS_FIREBASE_ADMIN_CONFIG="${config.sops.placeholder.apc_wss_firebase_admin_config}"
        export APC_WSS_GOOGLE_KMS_A3_SECRET_KEYRING="apc-wss-server"
        export APC_WSS_GOOGLE_KMS_A3_SECRET_KEY_NAME="a3-secret-encryption-key"
        export APC_WSS_A3_PG_HOST="anova-postgres-prod.cvgbnekce97r.us-west-2.rds.amazonaws.com"
        export APC_WSS_A3_PG_PORT="5432"
        export APC_WSS_A3_PG_USER="root"
        export APC_WSS_A3_PG_PASSWORD="${config.sops.placeholder.apc_wss_a3_pg_password}"
        export APC_WSS_A3_PG_DATABASE="anova_core_production"
      '';
    };
  };

  # Impermanence: Define what persists across reboots
  environment.persistence."/persist" = {
    hideMounts = true;

    directories = [
      "/var/log"
      "/var/lib/nixos"
      "/var/lib/systemd/coredump"
      "/var/lib/systemd/timers"
      "/var/lib/systemd/timesync"
      "/var/lib/systemd/rfkill"
      "/var/lib/docker"
      "/var/lib/NetworkManager"
      "/etc/NetworkManager/system-connections"
      "/var/lib/bluetooth"
      "/var/lib/tailscale"
      "/var/lib/cups"
      "/var/lib/fwupd"
      "/var/lib/AccountsService"
      "/var/lib/geoclue"
      "/var/lib/upower"
      "/var/lib/sddm"
    ];

    files = [
      "/etc/machine-id"
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
      "/etc/ssh/ssh_host_rsa_key"
      "/etc/ssh/ssh_host_rsa_key.pub"
      "/var/lib/systemd/random-seed"
    ];

    # Note: No users.joemitz section needed since /home is already persistent
    # via the @home subvolume mount. All user files persist automatically.
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
  #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
  #  wget
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # Enable ADB for Android development
  programs.adb.enable = true;

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = true;
      PermitRootLogin = "yes";
    };
  };

  # Enable Tailscale VPN
  services.tailscale.enable = true;

  # Enable NFS client support
  services.rpcbind.enable = true;

  # Enable Docker
  virtualisation.docker.enable = true;

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [ 22 ];
  networking.firewall.allowedUDPPorts = [ 41641 ]; # Tailscale
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    download-buffer-size = 536870912; # 512 MiB
  };

  # Enable polkit for system authorization
  security.polkit.enable = true;

  # Allow wheel group to use sudo without password
  security.sudo.wheelNeedsPassword = false;

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

  # Snapper - Btrfs snapshot management
  services.snapper = {
    configs = {
      home = {
        SUBVOLUME = "/home";
        ALLOW_USERS = [ "joemitz" ];
        TIMELINE_CREATE = true;
        TIMELINE_CLEANUP = true;
        TIMELINE_LIMIT_HOURLY = "48";    # Keep 48 hourly snapshots (2 days)
        TIMELINE_LIMIT_DAILY = "7";      # Keep 7 daily snapshots
        TIMELINE_LIMIT_WEEKLY = "4";     # Keep 4 weekly snapshots
        TIMELINE_LIMIT_MONTHLY = "12";   # Keep 12 monthly snapshots
        TIMELINE_LIMIT_YEARLY = "2";     # Keep 2 yearly snapshots
      };
      root = {
        SUBVOLUME = "/";
        ALLOW_USERS = [ "joemitz" ];
        TIMELINE_CREATE = true;
        TIMELINE_CLEANUP = true;
        TIMELINE_LIMIT_HOURLY = "48";    # Keep 48 hourly snapshots (2 days)
        TIMELINE_LIMIT_DAILY = "7";      # Keep 7 daily snapshots
        TIMELINE_LIMIT_WEEKLY = "4";     # Keep 4 weekly snapshots
        TIMELINE_LIMIT_MONTHLY = "12";   # Keep 12 monthly snapshots
        TIMELINE_LIMIT_YEARLY = "2";     # Keep 2 yearly snapshots
      };
      persist = {
        SUBVOLUME = "/persist";
        ALLOW_USERS = [ "joemitz" ];
        TIMELINE_CREATE = true;
        TIMELINE_CLEANUP = true;
        TIMELINE_LIMIT_HOURLY = "48";    # Keep 48 hourly snapshots (2 days)
        TIMELINE_LIMIT_DAILY = "7";      # Keep 7 daily snapshots
        TIMELINE_LIMIT_WEEKLY = "4";     # Keep 4 weekly snapshots
        TIMELINE_LIMIT_MONTHLY = "12";   # Keep 12 monthly snapshots
        TIMELINE_LIMIT_YEARLY = "2";     # Keep 2 yearly snapshots
      };
    };
  };

  # Mount NVMe drive (read-only)
  fileSystems."/mnt/nvme" = {
    device = "/dev/disk/by-uuid/8590c09a-138e-4615-b02d-c982580e3bf8";
    fsType = "btrfs";
    options = [ "subvol=@" "ro" ];
  };

  # Mount TrueNAS Plex share via NFS (read-only)
  fileSystems."/mnt/truenas/plex" = {
    device = "192.168.0.55:/mnt/main-pool/plex";
    fsType = "nfs";
    options = [ "ro" ];
  };
}
                                                                                                                                                                                                                 
