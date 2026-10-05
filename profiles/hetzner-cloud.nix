# Hetzner Cloud server with a single disk.
{ inputs }:

{
  imports = [
    inputs.srvos.nixosModules.hardware-hetzner-cloud
    inputs.srvos.nixosModules.server
    inputs.srvos.nixosModules.mixins-systemd-boot
    inputs.disko.nixosModules.disko
    (import ../disko/hetzner-cloud.nix { disks = [ "/dev/sda" ]; })
  ];

  boot.loader.efi.canTouchEfiVariables = true;
  services.openssh.settings.PermitRootLogin = "without-password";
}
