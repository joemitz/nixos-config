{ config, pkgs, ... }:

{
  programs.alacritty = {
    enable = true;
    theme = "moonfly";
    # settings = {
    #   colors.primary.background = "#000000";
    # };
  };
}
