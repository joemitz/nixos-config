{ config, pkgs, claude-code, tiny4linux, ... }:

{
  imports = [
    ./packages.nix
    ./git.nix
    ./ssh.nix
    ./direnv.nix
    ./bash.nix
    ./tmux.nix
    ./alacritty.nix
    ./firefox.nix
    ./desktop-entries.nix
  ];

  home.stateVersion = "25.11";
}
