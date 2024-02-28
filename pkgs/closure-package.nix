{ lib }:

{ fromPath
, fromStore ? "https://cache.nixos.org"
, ... # optional derivation attrs
} @ args:

let

  fetchSpec = ({
    inherit
      fromPath
      fromStore;
  }) // (lib.optionalAttrs (args ? toPath) {
    inherit (args) toPath;
  }) // (lib.optionalAttrs (args ? inputAddressed) {
    inherit (args) inputAddressed;
  });

  requiredArgNames = lib.attrNames fetchSpec;
  optionalDerivationAttrs = removeAttrs args requiredArgNames;

in

optionalDerivationAttrs // {
  /* need experimental nix:
    - after: https://github.com/NixOS/nix/pull/8370
    - static build: https://hydra.nixos.org/build/229213111

    nix profile install \
      /nix/store/ik8hqwxhj1q9blqf47rp76h7gw7s3060-nix-2.17.1-x86_64-unknown-linux-musl

    - /etc/nix/nix.conf: extra-experimental-features = fetch-closure
    - systemctl restart nix-daemon.service
  */
  outPath = builtins.fetchClosure fetchSpec;
}
