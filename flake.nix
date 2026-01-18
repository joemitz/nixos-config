{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    claude-code.url = "github:sadjow/claude-code-nix";
    impermanence.url = "github:nix-community/impermanence";

    # Pinned nixpkgs for tiny4linux to avoid rebuilds on Rust updates
    nixpkgs-tiny4linux.url = "github:NixOS/nixpkgs/2c3e5ec5df46d3aeee2a1da0bfedd74e21f4bf3a";

    # Pinned nixpkgs for handy to avoid rebuilds on flake updates
    nixpkgs-handy.url = "github:NixOS/nixpkgs/063f43f2dbdef86376cc29ad646c45c46e93234c";

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

  outputs = { nixpkgs, nixpkgs-tiny4linux, nixpkgs-handy, home-manager, claude-code, sops-nix, tiny4linux, impermanence, ... }: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
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
            pkgs-handy = import nixpkgs-handy {
              system = "x86_64-linux";
              config.allowUnfree = true;
            };
          };
        }
      ];
    };
  };
}
