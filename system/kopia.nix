{ pkgs, config, ... }:

{
  environment.systemPackages = [ pkgs.kopia ];

  # Create credentials file for HTTP basic auth and remote repository password
  sops.templates."kopia-server-control" = {
    owner = "root";
    mode = "0400";
    content = ''
      KOPIA_SERVER_USERNAME=joemitz
      KOPIA_SERVER_PASSWORD=kopia-local-pass
      KOPIA_PASSWORD=${config.sops.placeholder.kopia_password}
    '';
  };

  systemd.services.kopia-server = {
    description = "Kopia backup server";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      User = "root";
      Environment = "HOME=/root";
      EnvironmentFile = config.sops.templates."kopia-server-control".path;
      ExecStart = "${pkgs.kopia}/bin/kopia server start --address=https://127.0.0.1:51515 --tls-generate-cert --server-username=\${KOPIA_SERVER_USERNAME} --server-password=\${KOPIA_SERVER_PASSWORD}";

      # Auto-restart if it crashes
      Restart = "on-failure";
      RestartSec = "30s";
    };
  };
}
