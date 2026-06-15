{
  self,
  nixpkgs,
  home-manager,
}:
let
  pkgs = nixpkgs;

  mkGenericTest =
    name: suitePath:
    let
      suite = import suitePath {
        inherit pkgs home-manager;
        moonfin-flake = self;
      };
    in
    pkgs.testers.nixosTest {
      inherit name;
      nodes.machine = {
        imports = [
          {
            imports = [ home-manager.nixosModules.home-manager ];

            environment.systemPackages = with pkgs; [
            ];

            users.users.testuser = {
              isNormalUser = true;
              home = "/home/testuser";
              createHome = true;
              group = "users";
              uid = 1000;
            };

            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;

              users.testuser = {
                imports = [ suite.homeModule ];

                home.stateVersion = "25.11";
              };
            };
          }
        ];
      };

      testScript = ''
        machine.wait_for_unit("multi-user.target")
        machine.wait_for_unit("home-manager-testuser.service")
        ${suite.testScript}
      '';
    };

  suites = {
    "default" = ./default-install.nix;
  };
in
pkgs.lib.mapAttrs (name: path: mkGenericTest name path) suites
