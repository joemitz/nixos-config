_:

{
  # Enable numlock in KDE Plasma (0=on, 1=off, 2=unchanged)
  home.file.".config/kcminputrc".text = ''
    [Keyboard]
    NumLock=0
  '';

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

  xdg.desktopEntries.codium = {
    name = "VSCodium";
    exec = "codium --enable-features=WaylandWindowDecorations --ozone-platform-hint=auto %F";
    icon = "vscodium";
    terminal = false;
    categories = [ "Development" "IDE" "TextEditor" ];
    comment = "Code Editing. Redefined.";
    mimeType = [ "text/plain" "inode/directory" ];
  };
}
