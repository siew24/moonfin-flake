{ home-manager, self }:
{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.programs.moonfin;
in
{
  options = {
    programs.moonfin = {
      enable = lib.mkEnableOption "Enhanced Jellyfin & Emby client for mobile, tablet, and desktop";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ self.packages.${pkgs.stdenv.hostPlatform.system}.default ];
  };
}
