{ lib, ... }:

{
  # Plex NixOS Container
  # Portable declarative container for Plex Media Server
  # Configuration in ~/nixos-config/containers/plex.nix
  # Data stored in ~/Documents/plex/data/plex/config
  # Media bind mounted from /mnt/truenas/plex/*

  containers.plex = {
    autoStart = true;
    ephemeral = true;  # Container starts fresh each boot, data persists via bind mounts
    privateNetwork = false;  # Use host network (like Docker's network_mode: host)

    bindMounts = {
      # Plex configuration and library data
      "/config" = {
        hostPath = "/home/joemitz/Documents/plex/data/plex/config";
        isReadOnly = false;
      };

      # GPU device for hardware transcoding
      "/dev/dri" = {
        hostPath = "/dev/dri";
        isReadOnly = false;
      };

      # Media directories (read-only)
      "/media/movies" = {
        hostPath = "/mnt/truenas/plex/movies";
        isReadOnly = true;
      };
      "/media/shared-movies" = {
        hostPath = "/mnt/truenas/plex/shared-movies";
        isReadOnly = true;
      };
      "/media/tv" = {
        hostPath = "/mnt/truenas/plex/tv";
        isReadOnly = true;
      };
      "/media/mom-tv" = {
        hostPath = "/mnt/truenas/plex/mom-tv";
        isReadOnly = true;
      };
      "/media/mom-movies" = {
        hostPath = "/mnt/truenas/plex/mom-movies";
        isReadOnly = true;
      };
      "/media/shared-tv" = {
        hostPath = "/mnt/truenas/plex/shared-tv";
        isReadOnly = true;
      };
      "/media/studio-ghibli" = {
        hostPath = "/mnt/truenas/plex/studio-ghibli";
        isReadOnly = true;
      };
      "/media/harry-potter" = {
        hostPath = "/mnt/truenas/plex/harry-potter";
        isReadOnly = true;
      };
    };

    config = _: {
      system.stateVersion = "24.11";
      time.timeZone = "America/Los_Angeles";

      # Enable Plex Media Server
      services.plex = {
        enable = true;
        dataDir = "/config";
        openFirewall = true;  # Open port 32400
      };

      # Create plex user/group with specific UID/GID to match host permissions
      users.users.plex = {
        uid = lib.mkForce 1000;
        group = "plex";
        isSystemUser = true;
      };

      users.groups.plex = {
        gid = lib.mkForce 1000;
      };

      # Allow unfree packages (Plex is unfree)
      nixpkgs.config.allowUnfree = true;
    };
  };

  # Ensure data directory exists with correct permissions
  systemd.tmpfiles.rules = [
    "d /home/joemitz/Documents/plex/data/plex/config 0750 1000 1000 -"
  ];

  # Configure GPU device passthrough for hardware transcoding (declarative)
  systemd.services."container@plex" = {
    serviceConfig = {
      DeviceAllow = [
        "/dev/dri/card0 rw"
        "/dev/dri/renderD128 rw"
      ];
    };
  };
}
