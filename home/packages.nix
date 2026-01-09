{ config, pkgs, claude-code, tiny4linux, ... }:

{
  home.packages = [
    (pkgs.callPackage ../pkgs/tiny4linux.nix { src = tiny4linux; })
    claude-code.packages.x86_64-linux.default
    pkgs.gh
    pkgs.jq
    pkgs.vscodium
    pkgs.postman
    pkgs.zoom-us
    pkgs.devbox
    pkgs.tidal-hifi
    pkgs.guvcview
    pkgs.vlc
    pkgs.gimp
    pkgs.remmina
    pkgs.android-studio
    pkgs.android-tools
    pkgs.jdk11
    pkgs.patchelf
    pkgs.nodejs_24
    pkgs.micro
    pkgs.btop
    pkgs.eza
  ];
}
