{ attrs, ... }:

{
  config.home = {
    username = attrs.username;
    homeDirectory = attrs.homeDirectory or "/home/${attrs.username}";
  };
}
