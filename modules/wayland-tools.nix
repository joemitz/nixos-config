{ pkgs, ... }:

{
  # Essential Wayland utilities for Hyprland
  environment.systemPackages = with pkgs; [
    # Status bar and launcher
    waybar
    rofi
    dunst              # Notification daemon

    # Screenshot and recording utilities
    grim               # Screenshot tool for Wayland
    slurp              # Region selector for Wayland
    swappy             # Screenshot editor

    # Clipboard management
    wl-clipboard       # Wayland clipboard utilities
    wl-clip-persist    # Keep clipboard after app closes
    cliphist           # Clipboard history manager

    # Media control
    playerctl          # Media player controller

    # Wayland utilities
    wlrctl             # Wayland compositor control
    wtype              # Keyboard input simulation
    brightnessctl      # Backlight control (for hypridle)
  ];

  # Enable required services
  services.dbus.enable = true;
  programs.dconf.enable = true;
}
