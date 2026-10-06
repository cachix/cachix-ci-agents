# Hetzner dedicated server with BIOS boot and software RAID.
{ lib, ... }:

{
  boot.loader.grub.efiSupport = lib.mkForce false;
  boot.loader.grub.efiInstallAsRemovable = lib.mkForce false;

  boot.initrd.availableKernelModules = [
    "nvme"
    "md_mod"
    "raid1"
    "xhci_pci"
    "ahci"
  ];

  services.openssh.settings.PermitRootLogin = "without-password";

  # Use networkd instead of dhcpcd. The latter monitors Docker's
  # short-lived veth interfaces and can crash when they disappear.
  networking.useNetworkd = true;
}
