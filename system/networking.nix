_:

{
  networking.hostName = "nixos";

  # Enable networking
  networking.networkmanager.enable = true;

  # Enable Wake-on-LAN for enp6s0
  networking.interfaces.enp6s0.wakeOnLan.enable = true;

  # Open ports in the firewall
  networking.firewall.allowedTCPPorts = [ 22 51515 ]; # SSH, Kopia
  networking.firewall.allowedUDPPorts = [ 41641 ]; # Tailscale

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
