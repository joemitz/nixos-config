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
    };
  };
}
