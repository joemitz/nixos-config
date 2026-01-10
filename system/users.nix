{ ... }:

{
  # User accounts
  users.users.joemitz = {
    isNormalUser = true;
    description = "joemitz";
    extraGroups = [ "networkmanager" "wheel" "docker" "adbusers" "kvm" ];
    hashedPassword = "$6$cdmF4NEMLVzS4BDv$aK9lR1juxe512iK4SWVEFjailBjp96HThTA2zQkMRqOgThGISKIyA9x72Koa1qoVJ8VxbbHBZlni69BA9ZFKd/";
  };

  users.users.root = {
    hashedPassword = "$y$j9T$y2GlvoUIQM86.G9oHU4/P1$ig7BJtev.mK1LqGt73cNRURiqVsHlwViKS52WjuNnU/";
  };

  # Set your time zone
  time.timeZone = "America/Los_Angeles";

  # Select internationalisation properties
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Enable polkit for system authorization
  security.polkit.enable = true;

  # Allow wheel group to use sudo without password
  security.sudo.wheelNeedsPassword = false;
}
