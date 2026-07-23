{ inputs, sshKeys }:

let
  args = {
    inherit inputs sshKeys;
    lib = inputs.nixpkgs.lib;
  };
in
{
  linux = import ./linux.nix args;
  aarch64-linux = import ./aarch64-linux.nix args;
  macos = import ./macos.nix args;
}
