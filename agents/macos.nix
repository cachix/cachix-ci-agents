{ pkgs, lib, ... }:

{
  imports = [ ../common.nix ];

  nix.extraOptions = ''
    always-allow-substitutes = true
    experimental-features = flakes nix-command
  '';
  nix.settings.trusted-users = ["root" "hetzner"];

  networking.hostName = "macos";
  services.cachix-agent.enable = true;

  # required on M1
  programs.zsh.enable = true;
  programs.zsh.interactiveShellInit = ''
    eval "$(direnv hook zsh)"
  '';

  # Auto upgrade nix package and the daemon service.
  services.nix-daemon.enable = true;

  # Disable check for nixbld uid range.
  ids.uids.nixbld = 300;

  # for some reason manual isn't reproducible so we disable it
  documentation.man.enable = lib.mkForce false;
  documentation.info.enable = lib.mkForce false;
  documentation.doc.enable = lib.mkForce false;

  system.stateVersion = 5;
}
