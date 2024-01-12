#!/usr/bin/env -S nix eval --impure --file
# find the definition of ${package} in <nixpkgs>

/** the package name as a string */
{ package }:

let

  /* note that `nix eval` does not work with `--arg`; see:
    - https://github.com/NixOS/nix/issues/2678
    - https://github.com/NixOS/nix/pull/8992
  */
  attrPath = lib.splitString "." "${package}";

  /* load <nixpkgs>, need to be set up first!

    - Why channel? Because channels live in a human-readable, _constant_
      location such as `~/.nix-defexpr/channels`.

    - On the other hand, a flake always evaluate "in-store", due to its
      purity. So there is no way to get a nice location unless supplied
      explicitly by the user.
  */
  pkgs = import <nixpkgs> { };
  lib = pkgs.lib;

  nixpkgs = toString <nixpkgs>; ## human readable nixpkgs path
  storePath = toString pkgs.path; ## nixpkgs /nix/store path

  attrHost =
    let
      findAttrHost = lib.findFirst (lib.hasAttrByPath attrPath) { };
    in
    findAttrHost [
      pkgs
      lib
    ]; ## ^ find attrPath in the above attr "hosts"

  pkg = lib.getAttrFromPath attrPath attrHost;

  shortAttr = lib.last attrPath;
  parentAttr =
    let
      dropLast = list: with builtins;
        genList (i: elemAt list i) ((length list) - 1);
      parentPath = dropLast attrPath;
    in
    lib.getAttrFromPath parentPath attrHost;

  ## pkgs/stdenv/generic/make-derivation.nix
  ## pkgs/stdenv/generic/check-meta.nix
  getAttrPos = attrname: attrset:
    let
      pos = builtins.unsafeGetAttrPos attrname attrset;
    in
    "${pos.file}:${toString pos.line}:${toString pos.column}";

  storePosition = pkg.meta.position
    or (getAttrPos shortAttr parentAttr);

  relative =
    lib.removePrefix "/" (
      lib.removePrefix storePath storePosition
    );

in
{
  inherit
    relative
    nixpkgs
    ;
}
