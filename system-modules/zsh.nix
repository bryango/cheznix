{ nixosModulesPath, ... }:

{
  imports = [
    (nixosModulesPath + "/programs/zsh/zsh.nix")
    ./shells-env.nix
  ];
}
