{ config, lib, stdenv, ... }:

{
  imports = [ ../modules/common.nix ];

  nix.settings.trusted-users = ["hetzner"];

  networking.hostName = "macos";
  services.cachix-agent.enable = true;

  sops.secrets.github-runner-token.owner = "github-runner";

  cachix.github-runner = {
    enable = true;
    count = 2;
    githubOrganization = "cachix";
    namePrefix = "cachix-${stdenv.system}";
    tokenFile = config.sops.secrets.github-runner-token.path;
  };

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
