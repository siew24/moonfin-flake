{
  description = "Unofficial Nix Flake for Moonfin";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
    }:
    let
      linuxSystems = [ "x86_64-linux" ];

      supportedSystems = linuxSystems;

      forAllSystems =
        f: nixpkgs.lib.genAttrs supportedSystems (system: f nixpkgs.legacyPackages.${system});

    in
    {
      packages = forAllSystems (
        pkgs:
        import ./default.nix {
          inherit
            pkgs
            ;
        }
      );

      checks = nixpkgs.lib.genAttrs linuxSystems (
        system:
        import ./tests {
          inherit self home-manager;
          nixpkgs = nixpkgs.legacyPackages.${system};
        }
      );

      # homeModules = {
      # };
    };
}
