_:

{
  systemd.user.services.teams-for-linux = {
    Unit = {
      Description = "Microsoft Teams for Linux";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "/run/current-system/sw/bin/teams-for-linux";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
