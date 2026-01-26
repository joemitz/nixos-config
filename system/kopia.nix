{ pkgs, ... }:

{
  environment.systemPackages = [ pkgs.kopia ];

  systemd.services.kopia-server = {
    description = "Kopia backup server";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      User = "root";
      Environment = "HOME=/root";
      ExecStart = "${pkgs.kopia}/bin/kopia server start --address=http://0.0.0.0:51515 --insecure --without-password --ui --disable-csrf-token-checks";

      # Auto-restart if it crashes
      Restart = "on-failure";
      RestartSec = "30s";
    };
  };
}
