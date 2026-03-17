_:

{
  networking.hostName = "nixos";

  # Enable networking
  networking.networkmanager.enable = true;

  # Enable Wake-on-LAN for enp6s0
  networking.interfaces.enp6s0.wakeOnLan.enable = true;

  # Disable firewall (all ports open)
  networking.firewall.enable = false;

  # Enable the OpenSSH daemon
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = true;
    };
  };

  # Enable Tailscale VPN
  services.tailscale.enable = true;
}
