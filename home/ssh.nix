_:

{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks = {
      "macbook" = {
        hostname = "192.168.0.232";
        user = "joemitz";
      };
      "nixos-server" = {
        hostname = "192.168.0.115";
        user = "joemitz";
        extraOptions = {
          RemoteCommand = "/run/current-system/sw/bin/bash";
          RequestTTY = "yes";
          ServerAliveInterval = "60";
          ServerAliveCountMax = "3";
        };
      };
    };
  };
}
