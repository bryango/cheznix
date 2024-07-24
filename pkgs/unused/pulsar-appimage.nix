{ stdenv }:

let

  pname = "pulsar";
  version = "1.110.0";
  appimage = builtins.fetchClosure {
    /* artifact:
        https://github.com/pulsar-edit/pulsar/actions/runs/6527478252?pr=766
      - `nix store add-file`
      - `nix store make-content-addressed`
      - `echo "$storePath" | cachix push chezbryan`
    */
    fromStore = "https://chezbryan.cachix.org";
    # fromPath = /nix/store/1g0v9wczgps4inl7kcwljn8a5l0i9cl9-Linux.Pulsar-1.110.0.AppImage;
    fromPath = /nix/store/9ixywbwc16v96hx14acqsvwqfx7kyjm1-Linux.Pulsar-1.110.0.AppImage;
  };

in

stdenv.mkDerivation {
  inherit pname version;
  src = appimage;
  dontUnpack = true;
  installPhase = ''
    install -Dm644 $src $out/bin/pulsar
    chmod +x $out/bin/pulsar
  '';
  dontFixup = true;
}
