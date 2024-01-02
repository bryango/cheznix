# This package provides `tectonic.passthru.tests`.

{ lib
, fetchFromGitHub
, runCommand
, tectonic
, curl
, cacert
, emptyFile
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
    # which is not available in the current environment.
  '';
  buildInputs = [ curl cacert tectonic ];
  checkInternet = ''
    if curl --head "${tectonic.bundle.url}"; then
      set -e # continue to the tests defined below, fail on error
    else
      cat "${notice}"
      cp "${emptyFile}" "$out"
      exit # bail out gracefully
    fi
  '';

  fixedOutputTest = name: script: runCommand
    # Introduce randomness on purpose to force rebuild
    # See: https://github.com/figsoda/rand-nix/blob/main/default.nix
    "${name}-${builtins.readFile /proc/sys/kernel/random/uuid}"
    {
      /*
        Make a fixed-output derivation, return an `emptyFile` with fixed hash.
        These derivations are allowed to access the internet from within a
        sandbox, which allows us to test the automatic download of resource
        files in tectonic, as a side effect. A random name is generated to
        force rebuild of this fixed-output derivation.
      */
      inherit (emptyFile)
        outputHashAlgo
        outputHashMode
        outputHash
        ;
      preferLocalBuild = true;
      allowSubstitutes = false;
      inherit buildInputs;
    } ''
    ${checkInternet}
    ${script}
    cp "${emptyFile}" "$out"
  '';

in
{
  biber = fixedOutputTest "tectonic-biber-test" ''
    # import the test files
    cp "${testfiles}"/* .

    # tectonic caches in the $HOME directory, so set it to $PWD
    export HOME=$PWD
    tectonic -X compile ./test.tex
  '';

  workspace = fixedOutputTest "tectonic-workspace-test" ''
    tectonic -X new
    cat Tectonic.toml | grep "${tectonic.bundle.url}"
  '';
}
