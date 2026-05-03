{
  stdenv,
  variant,
  applicationName ? "Moonfin",
}:
let

  version = variant.version;
  url = variant.url;
  sha256 = variant.sha256;

  pname = "moonfin";
in
stdenv.mkDerivation {
  inherit pname version;

  src = builtins.fetchTarball {
    inherit url sha256;
  };
}
