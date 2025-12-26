{ pkgs, ... }:

{
  # Enable Hyprland window manager
  programs.hyprland = {
    enable = true;
    withUWSM = true;  # Universal Wayland Session Manager
  };

  # Wayland environment variables
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";            # Enable Wayland support in Electron/Chromium apps
    WLR_NO_HARDWARE_CURSORS = "1";   # Workaround for AMD GPU cursor issues
  };

  # Enable Hyprland lock screen and idle daemon
  programs.hyprlock.enable = true;
  services.hypridle.enable = true;

  # Hyprland utilities and tools
  environment.systemPackages = with pkgs; [
    pyprland         # Plugin system for scratchpads and utilities
    hyprpicker       # Color picker for Wayland
    hyprcursor       # Cursor theme manager
    hyprlock         # Screen locker
    hypridle         # Idle management daemon
    hyprpaper        # Wallpaper manager
    hyprpolkitagent  # PolicyKit authentication agent
  ];
}
