/**
  Materialize the flake inputs dependency tree as a directory tree.
  The symlink targets are /nix/store paths of the corresponding flake.
  `.follows` is not realized for the moment as it requires parsing
  `flake.nix` which may be an import from derivation.
*/

{
  lib,
  linkFarm,
  flakeSource,
  name ? "flake-inputs-tree",
}:

let
  getOutPath =
    node:
    let
      outPath = node.outPath or node.sourceInfo.outPath or null;
    in
    assert lib.assertMsg (outPath != null) "flake tree node is missing outPath or sourceInfo.outPath";
    toString outPath;

  assertSafeInputName =
    inputName:
    assert lib.assertMsg (
      inputName != "" && inputName != "." && inputName != ".." && !(lib.hasInfix "/" inputName)
    ) "unsafe flake input name for flake tree: ${inputName}";
    inputName;

  collectTreeEntries =
    relativePath: node:
    let
      sourceLink = if relativePath == "" then "source" else "${relativePath}/source";
      collectInputEntries =
        inputName: input:
        let
          safeName = assertSafeInputName inputName;
          inputPath =
            if relativePath == "" then "inputs/${safeName}" else "${relativePath}/inputs/${safeName}";
        in
        collectTreeEntries inputPath input;
    in
    [
      {
        name = sourceLink;
        path = getOutPath node;
      }
    ]
    ++ lib.concatLists (lib.mapAttrsToList collectInputEntries (node.inputs or { }));

in

linkFarm name (collectTreeEntries "" flakeSource)
