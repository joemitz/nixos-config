_:

{
  programs.ssh = {
    enable = true;
    settings = {
      "macbook" = {
        Hostname = "192.168.0.232";
        User = "joemitz";
      };
      "nixos-server" = {
        Hostname = "192.168.0.115";
        User = "joemitz";
        RemoteCommand = "/run/current-system/sw/bin/bash";
        RequestTTY = "yes";
        ServerAliveInterval = 60;
        ServerAliveCountMax = 3;
      };
    };
  };
}
