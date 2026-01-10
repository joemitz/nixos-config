{ ... }:

{
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
}
