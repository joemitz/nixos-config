{ pkgs, ... }:

{
  environment.systemPackages = [ pkgs.kopia ];

  # Create credentials file for server control
  environment.etc."kopia-server-control".text = ''
    KOPIA_SERVER_CONTROL_USER=admin
    KOPIA_SERVER_CONTROL_PASSWORD=password
  '';

  systemd.services.kopia-server = {
    description = "Kopia backup server";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      User = "root";
      Environment = "HOME=/root";
      EnvironmentFile = "/etc/kopia-server-control";
      ExecStart = "${pkgs.kopia}/bin/kopia server start --address=https://127.0.0.1:51515 --tls-generate-cert";

      # Auto-restart if it crashes
      Restart = "on-failure";
      RestartSec = "30s";
    };
  };
}
