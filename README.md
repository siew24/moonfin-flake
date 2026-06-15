# moonfin-flake
Unofficial Nix Flake for Moonfin

## Installation
Add the following input to your `flake.nix`:
```nix
inputs = {
  moonfin-flake = {
    url = "github:siew24/moonfin-flake";
    inputs = {
      nixpkgs.follows = "nixpkgs";
      home-manager.follows = "home-manager";
    };
  };
  # ...
}
```

And then add the following to your `/etc/nixos/configuration.nix`:

```nix
{ pkgs, moonfin-flake, ... }: {
  environment.systemPackages = [
    moonfin-flake.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}
```

Or, using `home-manager`:
```nix

# Add home manager import...
imports = [ moonfin-flake.homeModules.latest ];

# ...and then enable via:
programs.moonfin = {
  enable = true;
};
```
