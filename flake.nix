{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    claude-code.url = "github:sadjow/claude-code-nix";
    impermanence.url = "github:nix-community/impermanence";

    # Pinned nixpkgs for tiny4linux to avoid rebuilds on Rust updates
    nixpkgs-tiny4linux.url = "github:NixOS/nixpkgs/2c3e5ec5df46d3aeee2a1da0bfedd74e21f4bf3a";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    tiny4linux = {
      url = "github:OpenFoxes/Tiny4Linux/v2.2.1";
      flake = false;
    };
  };

  outputs = { nixpkgs, nixpkgs-unstable, nixpkgs-tiny4linux, home-manager, claude-code, sops-nix, tiny4linux, impermanence, ... }: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = {
        pkgs-unstable = import nixpkgs-unstable {
          system = "x86_64-linux";
          config.allowUnfree = true;
        };
      };
      modules = [
        ./system/index.nix
        sops-nix.nixosModules.sops
        impermanence.nixosModules.impermanence
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.joemitz = import ./home/index.nix;
          home-manager.extraSpecialArgs = {
            inherit claude-code tiny4linux;
            pkgs-tiny4linux = import nixpkgs-tiny4linux {
              system = "x86_64-linux";
              config.allowUnfree = true;
            };
          };
        }
      ];
    };
  };
}
