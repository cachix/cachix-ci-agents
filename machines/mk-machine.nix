# Turn an entry of the machine inventory into a machine for `lib.mkFlake`.
{ inputs, sshKeys }:

let
  inherit (inputs.nixpkgs) lib;

  runnerProfiles = {
    darwin = ../profiles/macos-runner.nix;
    nixos = ../profiles/linux-runner.nix;
  };

  agenixModules = {
    darwin = inputs.agenix.darwinModules.default;
    nixos = inputs.agenix.nixosModules.default;
  };
in
name:
{
  system,
  hardware,
  adminUsers ? [ "root" ],
  bootstrap ? null,
  defaultPackage ? false,
  modules ? [ ],
}:

let
  kind = if (lib.systems.elaborate system).isDarwin then "darwin" else "nixos";
in
{
  inherit system kind defaultPackage;

  bootstrap = lib.mapNullable (args: { hostname = name; } // args) bootstrap;

  modules = [
    runnerProfiles.${kind}
    agenixModules.${kind}
    {
      # Also the Cachix Deploy agent name.
      networking.hostName = name;

      cachix.machine = {
        inherit hardware adminUsers;
        adminKeys = lib.attrValues sshKeys.admins;
      };
    }
  ]
  ++ modules;
}
