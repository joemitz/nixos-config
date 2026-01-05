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

    # === ROOT WIPE (use @blank) ===
    # Delete all nested subvolumes recursively before removing root
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
    btrfs subvolume snapshot /mnt/@blank /mnt/@

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
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    theme = "breeze";
  };
  services.desktopManager.plasma6.enable = true;

  # Enable COSMIC Desktop Environment
  services.desktopManager.cosmic.enable = true;

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
    age.keyFile = "/persist-dotfiles/home/joemitz/.config/sops/age/keys.txt";

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
      "borg_passphrase" = { owner = "root"; mode = "0400"; };
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
  environment.persistence."/persist-root" = {
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
  };

  # Home impermanence - dotfiles (BROAD KDE-compatible persistence)
  environment.persistence."/persist-dotfiles" = {
    hideMounts = true;

    users.joemitz = {
      directories = [
        ".ssh"                    # SSH keys and known_hosts
        ".claude"                 # Claude Code data
        ".config"                 # All application configs including KDE Plasma
        ".local/share"            # Application data, KDE data, keyrings
        ".local/state"            # Application state, wireplumber
        ".android"                # Android Studio settings and AVDs
        ".mozilla"                # Firefox profiles and data
        ".var"                    # Flatpak app data
        ".vscode-oss"             # VSCodium settings and extensions
        ".zoom"                   # Zoom settings
        ".gradle"                 # Gradle build cache
        ".npm"                    # NPM package cache
        ".cargo"                  # Rust toolchain and cargo cache
        ".compose-cache"          # Docker compose cache
        ".java"                   # Java settings and cache
        ".react-native-cli"       # React Native CLI data
        ".crashlytics"            # Crashlytics cache
        ".nix-defexpr"            # Nix user environment definitions
        ".pki"                    # Certificate store
        ".icons"                  # Icon themes
        ".cache"                  # Application caches (KDE, browsers, dev tools)
      ];

      files = [
        ".git-credentials"                # Git credential store
        ".claude.json"                    # Claude Code config
        ".claude.json.backup"             # Claude Code config backup
        ".bash_history"                   # Command history
        ".bash_history_persistent"        # Persistent command history
        ".gtkrc-2.0"                      # GTK2 config
        ".npmrc"                          # NPM config
      ];
    };
  };

  # Home impermanence - userfiles
  environment.persistence."/persist-userfiles" = {
    hideMounts = true;

    users.joemitz = {
      directories = [
        "Android"           # Android SDK
        "anova"             # Anova project directory
        "nixos-config"      # NixOS configuration repo
        "Desktop"           # Desktop files
        "Documents"         # Documents
        "Downloads"         # Downloads
        "Pictures"          # Pictures
        "Videos"            # Videos
        "Music"             # Music
        "Templates"         # File templates
        "Public"            # Public share
        "Postman"           # Postman collections
        "Library"           # macOS-style library
        "misc"              # Miscellaneous files
        "ssh-backup"        # SSH backup folder
      ];

      files = [
        "borg-nixos-persist-key-backup"   # Borg backup encryption key
        "CLAUDE.md"                       # Claude Code instructions
      ];
    };
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
  #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
  #  wget
    # Override SDDM breeze theme background to match KDE Plasma Opal wallpaper
    (pkgs.writeTextDir "share/sddm/themes/breeze/theme.conf.user" ''
      [General]
      background=${pkgs.kdePackages.plasma-workspace-wallpapers}/share/wallpapers/Opal/contents/images/3840x2160.png
    '')
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
  # Only snapshot persist subvolumes (actual persistent data)
  # Removed: root, home (wiped on boot, snapshots are useless)
  services.snapper = {
    configs = {
      persist-root = {
        SUBVOLUME = "/persist-root";
        ALLOW_USERS = [ "joemitz" ];
        TIMELINE_CREATE = true;
        TIMELINE_CLEANUP = true;
        TIMELINE_LIMIT_HOURLY = "48";    # Keep 48 hourly snapshots (2 days)
        TIMELINE_LIMIT_DAILY = "7";      # Keep 7 daily snapshots
        TIMELINE_LIMIT_WEEKLY = "4";     # Keep 4 weekly snapshots
        TIMELINE_LIMIT_MONTHLY = "12";   # Keep 12 monthly snapshots
        TIMELINE_LIMIT_YEARLY = "2";     # Keep 2 yearly snapshots
      };

      persist-dotfiles = {
        SUBVOLUME = "/persist-dotfiles";
        ALLOW_USERS = [ "joemitz" ];
        TIMELINE_CREATE = true;
        TIMELINE_CLEANUP = true;
        TIMELINE_LIMIT_HOURLY = "48";    # Keep 48 hourly snapshots (2 days)
        TIMELINE_LIMIT_DAILY = "7";      # Keep 7 daily snapshots
        TIMELINE_LIMIT_WEEKLY = "4";     # Keep 4 weekly snapshots
        TIMELINE_LIMIT_MONTHLY = "12";   # Keep 12 monthly snapshots
        TIMELINE_LIMIT_YEARLY = "2";     # Keep 2 yearly snapshots
      };

      persist-userfiles = {
        SUBVOLUME = "/persist-userfiles";
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

  # Borg backup for all persist subvolumes (runs as root to access all system files)
  services.borgbackup.jobs."persist-backup" = {
    paths = [
      "/persist-root"        # System state
      "/persist-dotfiles"    # User dotfiles and configs
      "/persist-userfiles"   # User documents and projects
    ];

    exclude = [
      # Exclude all cache directories (can be rebuilt)
      "/persist-root/**/.cache"
      "/persist-dotfiles/home/joemitz/.cache"
      # Exclude build/download caches (can be rebuilt)
      "/persist-dotfiles/home/joemitz/.gradle"
      "/persist-dotfiles/home/joemitz/.npm"
      "/persist-dotfiles/home/joemitz/.cargo"
      "/persist-dotfiles/home/joemitz/.compose-cache"
      # Exclude Android Virtual Devices and cache (can be recreated)
      "/persist-dotfiles/home/joemitz/.android/avd"
      "/persist-dotfiles/home/joemitz/.android/cache"
      # Exclude KDE file indexer cache (rebuilds automatically)
      "/persist-dotfiles/home/joemitz/.local/share/baloo"
      # Exclude Trash and logs
      "/persist-dotfiles/home/joemitz/.local/share/Trash"
      "/persist-dotfiles/home/joemitz/.zoom/logs"
      # Exclude node_modules (can be rebuilt from package.json)
      "/persist-userfiles/**/node_modules"
      # Exclude Android build artifacts (can be rebuilt)
      "/persist-userfiles/**/build"
      "/persist-userfiles/**/.gradle"
      # Exclude iOS CocoaPods (can be rebuilt from Podfile.lock)
      "/persist-userfiles/**/Pods"
      # Exclude build output directories (can be rebuilt)
      "/persist-userfiles/**/dist"
      # Exclude test coverage reports (can be regenerated)
      "/persist-userfiles/**/coverage"
      # Docker images are large and can be rebuilt
      "/persist-root/var/lib/docker"
      # Exclude Snapper snapshots (redundant with Borg versioning, saves ~139GB)
      "/persist-root/.snapshots"
      "/persist-dotfiles/.snapshots"
      "/persist-userfiles/.snapshots"
    ];

    repo = "ssh://borg@192.168.0.100:2222/backup/nixos-persist";

    encryption = {
      mode = "repokey-blake2";
      passCommand = "cat ${config.sops.secrets.borg_passphrase.path}";
    };

    compression = "auto,lz4";

    startAt = "hourly";

    prune.keep = {
      hourly = 2;
      daily = 7;
      weekly = 4;
      monthly = 6;
      yearly = 2;
    };

    environment = {
      BORG_RSH = "ssh -i /home/joemitz/.ssh/id_ed25519_borg -o StrictHostKeyChecking=accept-new";
    };
  };
}
                                                                                                                                                                                                                 
