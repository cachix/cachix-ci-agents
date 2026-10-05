# Hetzner dedicated server, installed with bootstrap-hetzner.
{ lib, ... }:

{
  # TODO: This should also be set for bootstrapping
  boot.loader.grub.efiSupport = lib.mkForce false;
  boot.loader.grub.efiInstallAsRemovable = lib.mkForce false;

  # Use networkd instead of dhcpcd. The latter monitors Docker's
  # short-lived veth interfaces and can crash when they disappear.
  networking.useNetworkd = true;
}
