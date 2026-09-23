{ pkgs, pkgs-unstable, claude-code, tiny4linux, pkgs-tiny4linux, ... }:

let
  # Blank out the "letterpress" logo shown in an empty editor group (no tabs
  # open) so the pane is just its background color instead of the VSCodium logo.
  vscodium = pkgs.vscodium.overrideAttrs (oldAttrs: {
    postInstall = (oldAttrs.postInstall or "") + ''
      for variant in dark light hcDark hcLight; do
        f="$out/lib/vscode/resources/app/out/media/letterpress-$variant.svg"
        chmod +w "$f"
        echo '<svg xmlns="http://www.w3.org/2000/svg"></svg>' > "$f"
      done
    '';
  });
in
{
  home.packages = [

    # AWS
    pkgs.awscli2
    pkgs.awslogs

    # Android
    pkgs.android-studio
    pkgs.android-tools
    pkgs.jdk17
    pkgs.dotslash

    # Dev
    pkgs.watchman
    claude-code.packages.x86_64-linux.default
    pkgs-unstable.gemini-cli
    pkgs-unstable.opencode
    pkgs.nerd-fonts.jetbrains-mono
    pkgs.gh
    pkgs.github-copilot-cli
    vscodium
    pkgs.nodejs_24
    (pkgs.callPackage ../pkgs/devbox.nix { })
    pkgs.jq
    pkgs-unstable.postman

    # Nix
    pkgs.nixd
    pkgs.nixpkgs-fmt
    pkgs.nixf
    pkgs.statix
    pkgs.deadnix
    pkgs.sops
    pkgs.nvd

    # Media
    pkgs.audacity
    pkgs.tidal-hifi
    pkgs.vlc

    # Dictation
    pkgs-unstable.handy
    pkgs.dotool

    # Meetings
    (pkgs-tiny4linux.callPackage ../pkgs/tiny4linux.nix { src = tiny4linux; })
    pkgs.zoom-us
    pkgs.guvcview

    # Productivity
    pkgs.google-chrome
    pkgs.teams-for-linux
    pkgs.slack
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
