{
  description = "Unofficial Nix Flake for Moonfin";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      systems,
      home-manager,
    }:
    let
      eachSystem = f: nixpkgs.lib.genAttrs (import systems) (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = eachSystem (
        pkgs:
        import ./default.nix {
          inherit
            pkgs
            ;
        }
      );

      checks = nixpkgs.lib.genAttrs (import systems) (
        system:
        import ./tests {
          inherit self home-manager;
          nixpkgs = nixpkgs.legacyPackages.${system};
        }
      );

      homeModules = {
        latest = import ./hm-module { inherit self home-manager; };
      };
    };
}
