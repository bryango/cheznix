{ stdenvNoCC
, writeShellApplication
, replaceVars
, which
, name
, package
, lib
, concatText
, writeText
}:

(writeShellApplication {
  inherit name;
  runtimeInputs = [ stdenvNoCC which ];
  text = "";
}).overrideAttrs (prevAttrs: {

  ## do not generate `$textPath` automatically
  passAsFile = lib.remove "text" prevAttrs.passAsFile;

  ## manually pass `$textPath`
  textPath = concatText name [
    (writeText name prevAttrs.text)
    (replaceVars ./binary-fallback.sh {
      inherit name package;
    })
  ];

  ## hack `mv` such that `mv $textPath` works with no issue
  buildCommand = ''
    mv() { cp -a "$@"; }
  '' + prevAttrs.buildCommand;

})
