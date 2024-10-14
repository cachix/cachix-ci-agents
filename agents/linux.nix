{ config, pkgs, lib, ... }:

{
  imports = [
    ../modules/common.nix
    ../modules/github-runner.nix
  ];

  virtualisation.docker.enable = true;

  cachix.github-runner = {
    enable = true;
    count = 8;
    githubOrganization = "cachix";
    namePrefix = "cachix-${pkgs.stdenv.system}";
    extraGroups = [ "docker" ];
    tokenFile = config.sops.secrets.github-runner-token.path;
  };

  system.stateVersion = "23.11";
}
