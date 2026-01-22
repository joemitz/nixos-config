{ pkgs, claude-code, tiny4linux, pkgs-tiny4linux, ... }:

{
  home.packages = [
    
    # AWS
    pkgs.awscli2
    pkgs.awslogs

    # Android
    pkgs.android-studio
    pkgs.android-tools
    pkgs.jdk17

    # Dev
    claude-code.packages.x86_64-linux.default
    pkgs.nerd-fonts.jetbrains-mono
    pkgs.gh
    pkgs.vscodium
    pkgs.nodejs_24
    pkgs.devbox
    pkgs.jq
    pkgs.postman

    # Nix
    pkgs.nixd
    pkgs.nixpkgs-fmt
    pkgs.nixf
    pkgs.statix
    pkgs.deadnix
    pkgs.sops

    # Media
    pkgs.tidal-hifi
    pkgs.vlc

    # Meetings
    (pkgs-tiny4linux.callPackage ../pkgs/tiny4linux.nix { src = tiny4linux; })
    pkgs.zoom-us
    pkgs.guvcview

    # Productivity
    pkgs.teams-for-linux
    pkgs.gimp
    pkgs.thunderbird

    # Remote Desktop
    pkgs.remmina
    pkgs.parsec-bin

    # Terminal
    pkgs.btop
    pkgs.eza
  ];
}
