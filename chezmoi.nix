{ closurePackage
, symlinkJoin
, chezmoi
}:

let

  pname = "chezmoi";
  version = "2.38.0-acb8937";
  executable = closurePackage {
    /*
      - musl artifact: https://github.com/twpayne/chezmoi/actions/runs/6016856853
      - add to store: `nix store add-file`
      - ensure pushed: `nix store add-file chezmoi | cachix push chezbryan`
    */
    fromPath = /nix/store/dnzaicq1q4b6192ad9jhg5gnzakbz9z3-chezmoi;
    fromStore = "https://chezbryan.cachix.org";
    inputAddressed = false;
    pname = "${pname}-static";
    inherit version;
  };

in

symlinkJoin {
  inherit pname version;
  inherit (chezmoi) meta;
  name = "${pname}-${version}";
  paths = [ chezmoi ];
  postBuild = ''
    ## replace the executable
    cp -f "${executable}" $out/bin/${pname}
    ## keep everything else (e.g. shell completions)
  '';
}
