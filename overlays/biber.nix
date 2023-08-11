final: prev:

let

  inherit (final) closurePackage;

  biber217 = closurePackage {
    inherit (prev.biber) pname;
    version = "2.17";
    fromPath = /nix/store/pbv19v0mw57sxa7h6m1hzjvv33mdxxdf-perl5.36.0-biber-2.17;
  };

in

{

  inherit biber217;
  tectonic-with-biber = prev.callPackage ./../pkgs/tectonic-with-biber.nix {
    biber = biber217;
  };

}
