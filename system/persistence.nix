_:

{
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
      "/root/.config/kopia"
      "/root/.cache/kopia"
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
        ".ssh"                     # SSH keys and known_hosts
        ".claude"                  # Claude Code data
        ".aws"                     # AWS CLI configuration and credentials
        ".parsec"                  # Parsec remote desktop settings and credentials
        ".config"                  # All application configs including KDE Plasma
        ".local/share"             # Application data, KDE data, keyrings
        ".local/state"             # Application state, wireplumber
        ".android"                 # Android Studio settings and AVDs
        ".mozilla"                 # Firefox profiles and data
        ".vscode-oss"              # VSCodium settings and extensions
        ".zoom"                    # Zoom settings
        ".gradle"                  # Gradle build cache
        ".npm"                     # NPM package cache
        ".compose-cache"           # Docker compose cache
        ".java"                    # Java settings and cache
        ".react-native-cli"        # React Native CLI data
        ".pki"                     # Certificate store
        ".icons"                   # Icon themes
        ".cache"                   # Application caches (KDE, browsers, dev tools)
      ];

      files = [
        ".claude.json"             # Claude Code config
        ".claude.json.backup"      # Claude Code config backup
        ".bash_history"            # Command history
        ".bash_history_persistent" # Persistent command history
        ".gtkrc-2.0"               # GTK2 config
        ".npmrc"                   # NPM config
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
        "Postman"           # Postman collections
        "misc"              # Miscellaneous files
      ];

      files = [
        "CLAUDE.md"         # Claude Code instructions
      ];
    };
  };
}
