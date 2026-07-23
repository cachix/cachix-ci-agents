{ inputs, sshKeys, ... }:

{
  kind = "darwin";
  system = "aarch64-darwin";
  defaultPackage = true;

  modules = [
    ../profiles/macos-runner.nix
    inputs.agenix.darwinModules.default
    {
      networking.hostName = "macos";

      nix.settings.cores = 2;
      nix.settings.max-jobs = 4;

      users.users.hetzner.openssh.authorizedKeys.keys = builtins.attrValues sshKeys.admins;
    }
  ];
}
