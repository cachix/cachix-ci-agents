{ inputs }:

let
  sshKeys = import ../ssh-keys.nix;

  linuxModules = [
    inputs.srvos.nixosModules.server
    inputs.agenix.nixosModules.default
    ../profiles/cachix.nix
  ];

  disks = [
    "/dev/nvme0n1"
    "/dev/nvme1n1"
  ];
in
{
  gh-runner-x86_64-linux-01 = {
    system = "x86_64-linux";
    hardware = {
      cpus = 16;
      memory = 64;
      disk = 938;
    };
    modules = linuxModules ++ [
      inputs.disko.nixosModules.disko
      (import ../disko/mdadm.nix { inherit disks; })
      ../profiles/hetzner-dedicated.nix
      {
        users.users.root.openssh.authorizedKeys.keys = builtins.attrValues sshKeys.admins;
        boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
        system.stateVersion = "23.11";

        # Temporarily allow deployment to rename the host from "linux".
        srvos.detect-hostname-change.enable = false;
      }
    ];
  };

  gh-runner-aarch64-linux-01 = {
    system = "aarch64-linux";
    hardware = {
      cpus = 16;
      memory = 32;
      disk = 299;
    };
    modules = linuxModules ++ [
      (import ../profiles/hetzner-cloud.nix { inherit inputs; })
      {
        users.users.root.openssh.authorizedKeys.keys = builtins.attrValues sshKeys.admins;
        system.stateVersion = "23.11";
      }
    ];
  };

  gh-runner-aarch64-darwin-02 = {
    system = "aarch64-darwin";
    hardware = {
      cpus = 15;
      memory = 48;
      disk = 460;
    };
    modules = [
      ../profiles/cachix.nix
      inputs.agenix.darwinModules.default
      {
        users.users.russet281.openssh.authorizedKeys.keys = builtins.attrValues sshKeys.admins;
        nix.settings.trusted-users = [ "russet281" ];
        system.stateVersion = 5;
      }
    ];
  };
}
