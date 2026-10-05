# Hetzner Cloud server with a single disk.
{ inputs }:

{
  imports = [
    inputs.srvos.nixosModules.hardware-hetzner-cloud
    inputs.srvos.nixosModules.server
    inputs.srvos.nixosModules.mixins-systemd-boot
    inputs.disko.nixosModules.disko
    (import ../disko-hetzner-cloud.nix { disks = [ "/dev/sda" ]; })
  ];

  boot.loader.efi.canTouchEfiVariables = true;

  # TODO: Remove after the deployment that changes the hostname.
  srvos.detect-hostname-change.enable = false;
  services.openssh.settings.PermitRootLogin = "without-password";
}
