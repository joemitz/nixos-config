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

  # Allow unfree packages in imperative nix commands (nix-shell, nix-env, etc.)
  nixpkgs.config.allowUnfree = true;

  home.stateVersion = "25.11";
}
