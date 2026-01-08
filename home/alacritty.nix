{ config, pkgs, ... }:

{
  programs.alacritty = {
    enable = true;
    theme = "moonfly";
    settings = {
      colors.primary.background = "#000000";
      colors.normal.magenta = "#d79600ff";
      colors.bright.magenta = "#ffbf5fff";
    };
  };
}
