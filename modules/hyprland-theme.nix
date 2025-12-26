{ pkgs, ... }:

{
  # Catppuccin Macchiato Teal theme for Hyprland
  environment.variables = {
    GTK_THEME = "catppuccin-macchiato-teal-standard";
    XCURSOR_THEME = "Catppuccin-Macchiato-Teal";
    XCURSOR_SIZE = "24";
    HYPRCURSOR_THEME = "Catppuccin-Macchiato-Teal";
    HYPRCURSOR_SIZE = "24";
  };

  # Qt theming
  qt = {
    enable = true;
    platformTheme = "gtk2";
    style = "gtk2";
  };

  # Console colors (Catppuccin Macchiato palette)
  console = {
    earlySetup = true;
    colors = [
      "24273a"  # base
      "ed8796"  # red
      "a6da95"  # green
      "eed49f"  # yellow
      "8aadf4"  # blue
      "f5bde6"  # pink
      "8bd5ca"  # teal
      "cad3f5"  # text
      "5b6078"  # surface0
      "ed8796"  # red
      "a6da95"  # green
      "eed49f"  # yellow
      "8aadf4"  # blue
      "f5bde6"  # pink
      "8bd5ca"  # teal
      "a5adcb"  # subtext0
    ];
  };

  # Package overrides for Catppuccin variants
  nixpkgs.config.packageOverrides = pkgs: {
    catppuccin-gtk = pkgs.catppuccin-gtk.override {
      accents = [ "teal" ];
      size = "standard";
      variant = "macchiato";
    };
    colloid-icon-theme = pkgs.colloid-icon-theme.override {
      colorVariants = [ "teal" ];
    };
  };

  # Install theme packages
  environment.systemPackages = with pkgs; [
    catppuccin-gtk
    catppuccin-kvantum
    catppuccin-cursors.macchiatoTeal
    colloid-icon-theme
  ];
}
