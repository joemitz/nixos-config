{ config, pkgs, ... }:

{
  # Configure nixd language server for Nix
  # Provides IDE features: autocomplete, diagnostics, go-to-definition
  home.file.".config/nixd/config.json".text = builtins.toJSON {
    nixd = {
      nixpkgs = {
        expr = "import (builtins.getFlake \"/home/joemitz/nixos-config\").inputs.nixpkgs { }";
      };
      formatting = {
        command = [ "nixpkgs-fmt" ];
      };
      options = {
        nixos = {
          expr = "(builtins.getFlake \"/home/joemitz/nixos-config\").nixosConfigurations.nixos.options";
        };
        home-manager = {
          expr = "(builtins.getFlake \"/home/joemitz/nixos-config\").nixosConfigurations.nixos.options.home-manager.users.type.getSubOptions []";
        };
      };
    };
  };
}
