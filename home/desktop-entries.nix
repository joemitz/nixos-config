_:

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

  xdg.desktopEntries.kopia-ui-root = {
    name = "Kopia (Root)";
    exec = "pkexec kopia-ui";
    icon = "kopia-ui";
    terminal = false;
    categories = [ "System" ];
    comment = "Kopia Backup UI with root access for system backups";
  };
}
