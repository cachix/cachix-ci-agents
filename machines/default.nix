{ inputs, sshKeys }:

let
  mkMachine = import ./mk-machine.nix { inherit inputs sshKeys; };

  grubDevices = [
    "/dev/nvme0n1"
    "/dev/nvme1n1"
  ];
in
builtins.mapAttrs mkMachine {
  gh-runner-x86_64-linux-01 = {
    system = "x86_64-linux";
    hardware = {
      cpus = 16;
      memory = 64;
      disk = 938;
    };
    bootstrap = {
      diskoDevices = import ../disko-mdadm.nix { disks = grubDevices; };
      inherit grubDevices;
      sshPubKey = sshKeys.admins.domen;
    };
    modules = [
      ../profiles/hetzner-dedicated.nix
      { boot.binfmt.emulatedSystems = [ "aarch64-linux" ]; }
    ];
  };

  gh-runner-aarch64-linux-01 = {
    system = "aarch64-linux";
    hardware = {
      cpus = 16;
      memory = 32;
      disk = 299;
    };
    modules = [ (import ../profiles/hetzner-cloud.nix { inherit inputs; }) ];
  };

  gh-runner-aarch64-darwin-01 = {
    system = "aarch64-darwin";
    hardware = {
      cpus = 8;
      memory = 16;
      disk = 228;
    };
    adminUsers = [ "hetzner" ];
    # Limit each build to 2 of the 8 CPUs.
    modules = [ { cachix.machine.cores = 2; } ];
  };

  gh-runner-aarch64-darwin-02 = {
    system = "aarch64-darwin";
    hardware = {
      cpus = 15;
      memory = 48;
      disk = 460;
    };
    adminUsers = [ "russet281" ];
  };
}
