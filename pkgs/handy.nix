{ lib
, appimageTools
, fetchurl
}:

let
  pname = "handy";
  version = "0.6.11";

  src = fetchurl {
    url = "https://github.com/cjpais/Handy/releases/download/v${version}/Handy_${version}_amd64.AppImage";
    hash = "sha256-HpVZCCyT0XxJN+DyHVdkHGKy09MHTfhBpuuINnSnGt4=";
  };

  appimageContents = appimageTools.extractType2 {
    inherit pname version src;
  };
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraPkgs = pkgs: with pkgs; [
    gtk3
    glib
  ];

  multiArch = false;

  # Bind Wayland socket for proper display authorization
  extraBwrapArgs = [
    "--ro-bind-try /run/user/1000/wayland-0 /run/user/1000/wayland-0"
    "--ro-bind-try /run/user/1000/wayland-1 /run/user/1000/wayland-1"
    "--setenv GDK_BACKEND wayland"
  ];

  extraInstallCommands = ''
    install -Dm444 ${appimageContents}/Handy.desktop $out/share/applications/handy.desktop
    install -Dm444 ${appimageContents}/Handy.png $out/share/pixmaps/handy.png
  '';

  meta = {
    description = "Free, open source, and extensible speech-to-text application that works completely offline";
    homepage = "https://handy.computer";
    license = lib.licenses.agpl3Plus;
    platforms = [ "x86_64-linux" ];
    mainProgram = "handy";
  };
}
