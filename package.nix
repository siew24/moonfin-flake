{
  lib,
  variant,
  pkgs,
  makeDesktopItem,
  fetchFromGitHub,
  copyDesktopItems,
  flutter341,
}:
let
  pname = "moonfin";
  version = variant.version;
  pubspecLock = lib.importJSON ./pubspec.lock.json;
in
flutter341.buildFlutterApplication {
  inherit pname version pubspecLock;

  src = fetchFromGitHub {
    owner = "Moonfin-Client";
    repo = "Moonfin-Core";
    rev = variant.sha1;
    hash = variant.sha256;
  };

  desktopItems = makeDesktopItem {
    name = "moonfin";
    desktopName = "Moonfin";
    exec = "moonfin";
    icon = "moonfin";
    type = "Application";
    categories = [
      "AudioVideo"
      "Video"
      "Player"
    ];
    startupNotify = true;
    terminal = false;
  };

  nativeBuildInputs = [ copyDesktopItems ];

  buildInputs = with pkgs; [
    alsa-lib
    mpv-unwrapped
    libass
    ffmpeg-headless
    libplacebo
    libunwind
    shaderc
    vulkan-loader
    lcms2
    libdovi
    libdvdnav
    libdvdread
    libdvdcss
    mujs
    libbluray
    lua
    rubberband
    libuchardet
    zimg
    openal
    pipewire
    libpulseaudio
    libcaca
    libdrm
    libdisplay-info
    libgbm
    libxscrnsaver
    libxpresent
    nv-codec-headers-12
    libva
    libvdpau
  ];

  # postPatch = ''
  #   substituteInPlace linux/CMakeLists.txt \
  #     --replace-fail 'target_compile_options(''${TARGET} PRIVATE -Wall -Werror)' 'target_compile_options(''${TARGET} PRIVATE -Wall -Werror -Wno-deprecated)'
  # '';

  meta = {
    description = "Enhanced Jellyfin & Emby client for mobile, tablet, and desktop";
    homepage = "https://github.com/Moonfin-Client/Moonfin-Core";
    changelog = "https://github.com/Moonfin-Client/Moonfin-Core/releases";
    license = lib.licenses.gpl3;
  };
}
