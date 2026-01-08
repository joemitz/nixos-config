{ config, pkgs, ... }:

{
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

  # Success and failure notification services (triggered by systemd)
  systemd.services."borgbackup-job-persist-backup" = {
    unitConfig = {
      OnSuccess = "borg-backup-success-notify.service";
      OnFailure = "borg-backup-failure-notify.service";
    };
    serviceConfig = {
      # Automatic retry on failure
      Restart = "on-failure";
      RestartSec = "2min";          # Wait 2 minutes between retries
      StartLimitBurst = 3;          # Max 3 retry attempts
      StartLimitIntervalSec = "1h"; # Reset retry counter after 1 hour
    };
  };

  systemd.services."borg-backup-success-notify" = {
    description = "Send notification on Borg backup success";
    serviceConfig = {
      Type = "oneshot";
      User = "joemitz";
      Environment = "DISPLAY=:0";
    };
    script = ''
      TIMESTAMP=$(date '+%H:%M:%S')
      DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus \
        ${pkgs.libnotify}/bin/notify-send \
        --urgency=low \
        --expire-time=0 \
        "Borg Backup Success" \
        "Backup completed at $TIMESTAMP"
    '';
  };

  systemd.services."borg-backup-failure-notify" = {
    description = "Send notification on Borg backup failure";
    serviceConfig = {
      Type = "oneshot";
      User = "joemitz";
      Environment = "DISPLAY=:0";
    };
    script = ''
      TIMESTAMP=$(date '+%H:%M:%S')
      DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus \
        ${pkgs.libnotify}/bin/notify-send \
        --urgency=critical \
        "Borg Backup FAILED at $TIMESTAMP" \
        "Check logs: journalctl -u borgbackup-job-persist-backup"
    '';
  };
}
