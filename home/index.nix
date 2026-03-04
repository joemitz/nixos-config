{ ... }:

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
    ./nixd.nix
    ./autostart.nix
  ];

  home.stateVersion = "25.11";
}
