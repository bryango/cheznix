# This package provides `tectonic.passthru.tests`.

{ lib
, fetchFromGitHub
, runCommand
, tectonic
, curl
, cacert
}:

let
  /*
    Currently, the test files are only fully available from the `dev` branch of
    `biber`. When https://github.com/plk/biber/pull/467 is eventually released,
    we can obtain the test files from `texlive.pkgs.biber.texsource`. For now,
    we fetch the test files directly from GitHub.
  */
  biber-dev-source = fetchFromGitHub {
    owner = "plk";
    repo = "biber";
    rev = "dev";
    hash = "sha256-GfNV4wbRXHn5qCYhrf3C9JPP1ArLAVSrJF+3iIJmYPI=";
  };
  testfiles = "${biber-dev-source}/testfiles";

  notice = builtins.toFile "tectonic-offline-notice" ''
    # To fetch tectonic's web bundle, the tests require internet access,
    # which is not available in a build sandbox. To run the tests, try:
    # `nix-build --no-sandbox --attr tectonic.passthru.tests`
  '';
  buildInputs = [ curl cacert tectonic ];
  checkInternet = ''
    if curl --head "${tectonic.TECTONIC_WEB_BUNDLE_LOCKED}"; then
      : # continue to the tests defined below
    else
      cat "${notice}"
      cp "${notice}" "$out"
      exit # bail out gracefully
    fi
  '';

in
{
  biber = runCommand "tectonic-biber-test.pdf" {
    inherit buildInputs;
  } ''
    ${checkInternet}

    # import the test files
    cp "${testfiles}"/* .

    # tectonic caches in the $HOME directory, so set it to $PWD
    export HOME=$PWD
    tectonic -X compile ./test.tex

    mv ./test.pdf $out
  '';

  workspace = runCommand "tectonic-workspace-test" {
    inherit buildInputs;
  } ''
    ${checkInternet}
    tectonic -X new $out
    cat $out/Tectonic.toml | grep "${tectonic.TECTONIC_WEB_BUNDLE_LOCKED}"
  '';
}
