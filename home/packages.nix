{ pkgs, claude-code, tiny4linux, ... }:

{
  home.packages = [
    (pkgs.callPackage ../pkgs/tiny4linux.nix { src = tiny4linux; })
    claude-code.packages.x86_64-linux.default
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
    pkgs.android-studio
    pkgs.android-tools
    pkgs.jdk11
    pkgs.nodejs_24
    pkgs.btop
    pkgs.eza
    pkgs.nixd
    pkgs.nixpkgs-fmt
    pkgs.nixf
    pkgs.statix
    pkgs.deadnix

    # Kopia UI wrapped to use capability-enabled kopia binary
    (pkgs.symlinkJoin {
      name = "kopia-ui-wrapped";
      paths = [ pkgs.kopia-ui ];
      buildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/kopia-ui \
          --prefix PATH : /run/wrappers/bin
      '';
    })
  ];
}
