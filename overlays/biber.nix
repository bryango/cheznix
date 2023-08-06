final: prev:

let

  biber217 = {
    inherit (prev.biber) pname;
    version = "2.17";
    outPath = builtins.fetchClosure {
      /* need experimental nix:
        - after: https://github.com/NixOS/nix/pull/8370
        - static build: https://hydra.nixos.org/build/229213111

        nix profile install \
          /nix/store/ik8hqwxhj1q9blqf47rp76h7gw7s3060-nix-2.17.1-x86_64-unknown-linux-musl

        - /etc/nix/nix.conf: extra-experimental-features = fetch-closure
        - systemctl restart nix-daemon.service
      */
      inputAddressed = true;
      fromStore = "https://cache.nixos.org";
      fromPath = /nix/store/pbv19v0mw57sxa7h6m1hzjvv33mdxxdf-perl5.36.0-biber-2.17;
      ## ^ from: https://hydra.nixos.org/build/202359527#tabs-details
    };
  };

in

{

  inherit biber217;
  tectonic-with-biber = prev.callPackage ./../pkgs/tectonic-with-biber.nix {
    biber = biber217;
  };

}
