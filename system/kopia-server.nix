{ pkgs, ... }:

{
  # Kopia Repository Server
  # Runs as root to access all system files
  # kopia-ui connects to this local server instead of directly to the remote repository

  systemd.services.kopia-server = {
    description = "Kopia Repository Server";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      User = "root";
      Group = "root";

      # Set HOME for kopia config
      Environment = "HOME=/root";

      # Start kopia server on localhost
      # User joemitz can connect from kopia-ui using the password from secrets
      # --insecure flag is safe for localhost connections
      ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.kopia}/bin/kopia server start --insecure --address=127.0.0.1:51515 --server-username=joemitz --server-password=$(cat /run/secrets/kopia-server-password)'";

      # Restart on failure
      Restart = "on-failure";
      RestartSec = "30s";

      # Security hardening
      NoNewPrivileges = false; # Need privileges to read system files
      PrivateTmp = true;
    };
  };

  # Automated hourly backups of persistence directories
  systemd.services.kopia-backup = {
    description = "Kopia Automated Backup";
    after = [ "kopia-server.service" ];
    wants = [ "kopia-server.service" "network-online.target" ];

    serviceConfig = {
      Type = "oneshot";
      User = "root";
      Group = "root";

      # Restart on failure with retries (like Borg)
      Restart = "on-failure";
      RestartSec = "2m";
      StartLimitBurst = 3;
      StartLimitIntervalSec = "10m";
    };

    # Only run within first 5 minutes of the hour (prevents catch-up after suspend/wake)
    preStart = ''
      current_minute=$(date +%M)
      if [ "$current_minute" -ge 5 ]; then
        echo "Current time is past the 5-minute window. Skipping backup."
        exit 0
      fi
    '';

    script = ''
      set -e

      echo "Starting Kopia backup at $(date)"

      # Snapshot the three persistence subvolumes
      ${pkgs.kopia}/bin/kopia snapshot create /persist-root --description "System state"
      ${pkgs.kopia}/bin/kopia snapshot create /persist-dotfiles --description "User configs and app data"
      ${pkgs.kopia}/bin/kopia snapshot create /persist-userfiles --description "User documents and projects"

      echo "Kopia backup completed successfully at $(date)"
    '';

    # Desktop notifications
    postStop = ''
      if [ "$EXIT_STATUS" = "0" ] || [ "$SERVICE_RESULT" = "success" ]; then
        /run/current-system/sw/bin/sudo -u joemitz DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus \
          /run/current-system/sw/bin/notify-send \
          -u low \
          -t 5000 \
          "Kopia Backup" \
          "Backup completed successfully"
      else
        /run/current-system/sw/bin/sudo -u joemitz DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus \
          /run/current-system/sw/bin/notify-send \
          -u critical \
          "Kopia Backup Failed" \
          "Check systemctl status kopia-backup.service"
      fi
    '';
  };

  # Timer to run backups hourly
  systemd.timers.kopia-backup = {
    description = "Hourly Kopia Backup Timer";
    wantedBy = [ "timers.target" ];

    timerConfig = {
      OnCalendar = "hourly";
      Persistent = true;
      RandomizedDelaySec = "5m";
    };
  };
}
