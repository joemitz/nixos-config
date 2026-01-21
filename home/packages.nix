{ pkgs, claude-code, tiny4linux, pkgs-tiny4linux, ... }:

{
  home.packages = [
    (pkgs-tiny4linux.callPackage ../pkgs/tiny4linux.nix { src = tiny4linux; })
    claude-code.packages.x86_64-linux.default
    pkgs.nerd-fonts.jetbrains-mono
    pkgs.gh
    pkgs.jq
    pkgs.awscli2
    pkgs.awslogs
    pkgs.vscodium
    pkgs.postman
    pkgs.zoom-us
    pkgs.devbox
    pkgs.tidal-hifi
    pkgs.guvcview
    pkgs.vlc
    pkgs.gimp
    pkgs.remmina
    pkgs.parsec-bin
    pkgs.android-studio
    pkgs.android-tools
    pkgs.jdk17
    pkgs.nodejs_24
    pkgs.btop
    pkgs.eza
    pkgs.nixd
    pkgs.nixpkgs-fmt
    pkgs.nixf
    pkgs.statix
    pkgs.deadnix
    pkgs.sops
  ];
}
