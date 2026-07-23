{
  lib,
  inputs,
  sshKeys,
}:
let
  grubDevices = [
    "/dev/nvme0n1"
    "/dev/nvme1n1"
  ];
in
{
  kind = "nixos";
  system = "x86_64-linux";
  defaultPackage = true;

  bootstrap = {
    hostname = "linux";
    diskoDevices = import ../disko-mdadm.nix { disks = grubDevices; };
    inherit grubDevices;
    sshPubKey = sshKeys.admins.domen;
  };

  modules = [
    ../profiles/linux-runner.nix
    inputs.agenix.nixosModules.default
    {
      # TODO: This should also be set for bootstrapping
      boot.loader.grub.efiSupport = lib.mkForce false;
      boot.loader.grub.efiInstallAsRemovable = lib.mkForce false;
      boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

      users.users.root.openssh.authorizedKeys.keys = builtins.attrValues sshKeys.admins;
    }
  ];
}
