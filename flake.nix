{
  description = "NixOS configuration with Claude Code via home-manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    claude-code.url = "github:sadjow/claude-code-nix";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    tiny4linux = {
      url = "github:OpenFoxes/Tiny4Linux/v2.2.2";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, home-manager, claude-code, sops-nix, tiny4linux, ... }: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        sops-nix.nixosModules.sops
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.joemitz = import ./home.nix;
          home-manager.extraSpecialArgs = {
            inherit claude-code tiny4linux;
          };
        }
      ];
    };
  };
}
