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
      ExecStart = "${pkgs.kopia}/bin/kopia server start --address=https://127.0.0.1:51515 --tls-generate-cert";

      # Auto-restart if it crashes
      Restart = "on-failure";
      RestartSec = "30s";
    };
  };
}
