{ pkgs, ... }:

{
  # Enable the X11 windowing system
  # You can disable this if you're only using the Wayland session
  services.xserver.enable = true;

  # Enable the KDE Plasma Desktop Environment
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    theme = "breeze";
  };
  services.desktopManager.plasma6.enable = true;

  # Enable native Wayland support for Electron apps (Slack, etc.)
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # Enable XDG Desktop Portal for screen sharing on Wayland
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-wlr
      xdg-desktop-portal-gtk
    ];
  };

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable CUPS to print documents
  services.printing.enable = true;

  # Enable sound with pipewire
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;
  };

  # Override SDDM breeze theme background to match KDE Plasma Opal wallpaper
  environment.systemPackages = with pkgs; [
    kde-rounded-corners
    (pkgs.writeTextDir "share/sddm/themes/breeze/theme.conf.user" ''
      [General]
      background=${pkgs.kdePackages.plasma-workspace-wallpapers}/share/wallpapers/Opal/contents/images/3840x2160.png
    '')
  ];
}
