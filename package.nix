{
  lib,
  variant,
  pkgs,
  makeDesktopItem,
  fetchFromGitHub,
  flutter,
}:
let
  pname = "moonfin";
  version = variant.version;
  pubspecLock = lib.importJSON ./pubspec.lock.json;

in
flutter.buildFlutterApplication {
  inherit pname version pubspecLock;

  src = fetchFromGitHub {
    owner = "Moonfin-Client";
    repo = "Mobile-Desktop";
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

  postPatch = ''
    substituteInPlace linux/CMakeLists.txt \
      --replace-fail 'target_compile_options(''${TARGET} PRIVATE -Wall -Werror)' 'target_compile_options(''${TARGET} PRIVATE -Wall -Werror -Wno-deprecated)'
  '';

  meta = {
    description = "Enhanced Jellyfin & Emby client for mobile, tablet, and desktop";
    homepage = "https://github.com/Moonfin-Client/Mobile-Desktop";
    changelog = "https://github.com/Moonfin-Client/Mobile-Desktop/releases";
  };
}
