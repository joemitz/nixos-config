{ config, pkgs, ... }:

{
  programs.alacritty = {
    enable = true;
    theme = "moonfly";
    settings = {
      colors.primary.background = "#000000";
      colors.normal.magenta = "#d74f00";
      colors.bright.magenta = "#ff8c5f";
    };
  };
}
