{ config, pkgs, ... }:

{
  xdg.desktopEntries.guvcview = {
    name = "guvcview";
    exec = "guvcview -z";
    icon = "guvcview";
    terminal = false;
    categories = [ "AudioVideo" "Video" ];
    comment = "GTK UVC Viewer";
  };

  xdg.desktopEntries.tiny4linux = {
    name = "Tiny4Linux";
    exec = "tiny4linux-gui";
    icon = "camera-video";
    terminal = false;
    categories = [ "AudioVideo" "Video" ];
    comment = "Control OBSBOT Tiny2 camera";
  };
}
