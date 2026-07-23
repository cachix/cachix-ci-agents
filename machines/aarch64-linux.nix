{ inputs, sshKeys, ... }:

{
  kind = "nixos";
  system = "aarch64-linux";
  defaultPackage = true;

  modules = [
    inputs.srvos.nixosModules.hardware-hetzner-cloud
    inputs.srvos.nixosModules.server
    inputs.srvos.nixosModules.mixins-systemd-boot
    inputs.disko.nixosModules.disko
    inputs.agenix.nixosModules.default
    ../profiles/linux-runner.nix
    (import ../disko-hetzner-cloud.nix { disks = [ "/dev/sda" ]; })
    {
      services.cachix-agent.enable = true;
      boot.loader.efi.canTouchEfiVariables = true;
      networking.hostName = "aarch64-linux";
      users.users.root.openssh.authorizedKeys.keys = builtins.attrValues sshKeys.admins;
      services.openssh.enable = true;
      services.openssh.settings.PermitRootLogin = "without-password";

      # Try to limit memory usage.
      nix.settings.max-jobs = 8;
    }
  ];
}
