{ moonfin-flake, ... }: {
  homeModule = {
    imports = [ moonfin-flake.homeModules.latest ];

    programs.moonfin = {
      enable = true;
    };
  };

  testScript = ''
    machine.succeed("cat /etc/profiles/per-user/testuser/share/applications/moonfin.desktop")
  '';
}
