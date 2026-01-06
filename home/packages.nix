{ config, pkgs, pkgs-unstable, claude-code, tiny4linux, ... }:

{
  home.packages = [
    (pkgs.callPackage ../pkgs/tiny4linux.nix { src = tiny4linux; })
    claude-code.packages.x86_64-linux.default
    pkgs.gh
    pkgs.jq
    pkgs.vscodium
    pkgs.postman
    pkgs.zoom-us
    pkgs.vorta
    pkgs.devbox
    pkgs.tidal-hifi
    pkgs.guvcview
    pkgs.vlc
    pkgs.remmina
    pkgs.patchelf
    pkgs.nodejs_24
    pkgs.micro
    pkgs.btop
    pkgs.eza
    pkgs.lazygit

    # Use unstable packages for Android/Gradle to get PR #449037 fix
    pkgs-unstable.android-studio
    pkgs-unstable.android-tools
  ];
}
