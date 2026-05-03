{
  pkgs ? import <nixpkgs> { },
  system ? pkgs.stdenv.hostPlatform.system,
}:
let
  variant = (builtins.fromJSON (builtins.readFile ./sources.json)).variants.linux;
in
{
  default = pkgs.callPackage ./package.nix {
    inherit variant;
  };
}
