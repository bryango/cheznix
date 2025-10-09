{ lib
, bash
, python3
, rustPlatform
, emptyDirectory
, source ? with lib.fileset; toSource {
    root = ./.;
    fileset = difference ./. (maybeMissing ./target);
  }
, isDevShell ? source == null
, installShellFiles
, stdenv
, gh
, cargo
, clippy
, nixfmt-rfc-style
}:

let

  packageVersion = with builtins; (fromTOML (readFile "${source}/Cargo.toml")).package.version;

  # append git revision to the version string, if available
  versionSuffix =
    if (source ? dirtyShortRev || source ? shortRev) then
      "-g${source.dirtyShortRev or source.shortRev}"
    else
      "";

  version = "${packageVersion}${versionSuffix}";
  mainProgram = "niz";

in

(rustPlatform.buildRustPackage
  {
    pname = mainProgram;
    inherit version;

    src = source;
    cargoDeps = rustPlatform.importCargoLock {
      lockFile = "${source}/Cargo.lock";
    };

    nativeBuildInputs = [
      # pkg-config
      installShellFiles
    ];

    buildInputs = [
      bash
      python3
      gh # for pr checker
    ];

    postInstall = lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
      installShellCompletion --cmd ${mainProgram} \
        --bash <($out/bin/${mainProgram} completions bash) \
        --fish <($out/bin/${mainProgram} completions fish) \
        --zsh <($out/bin/${mainProgram} completions zsh)
    '';

    meta = {
      inherit mainProgram;
      # `description` necessary for `meta.position` and stuff
      description = "Helper utilities for Nix related tasks";
      platforms = lib.platforms.unix;
      license = lib.licenses.gpl3Plus;
      maintainers = with lib.maintainers; [ bryango ];
    };
  }).overrideAttrs
  ({ nativeBuildInputs ? [ ], buildInputs ? [ ], env ? { }, ... }@_prevAttrs: lib.optionalAttrs isDevShell {
    # prevent devShell dependence on the source
    src = emptyDirectory;
    cargoDeps = emptyDirectory;
    version = "0-unstable-dev";

    nativeBuildInputs = [
      cargo # with shell completions, instead of cargo-auditable
      clippy # more lints for better rust code
      nixfmt-rfc-style # for formatting nix code
    ] ++ nativeBuildInputs ++ buildInputs;

    env = env // {
      # for developments, e.g. symbol lookup in std library
      RUST_SRC_PATH = "${rustPlatform.rustLibSrc}";
      # for debugging
      RUST_LIB_BACKTRACE = "1";
    };

  })
