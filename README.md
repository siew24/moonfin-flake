# moonfin-flake
Unofficial Nix Flake for Moonfin

## Installation
Add the following to your `flake.nix`:
```
inputs = {
  moonfin = {
    url = "github:siew24/moonfin-flake";
    inputs = {
      nixpkgs.follows = "nixpkgs";
      home-manager.follows = "home-manager";
    };
  };
  # ...
}
```
