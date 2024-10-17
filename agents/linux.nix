{ config, pkgs, lib, ... }:

{
  imports = [
    ../modules/common.nix
    ../modules/github-runner.nix
  ];

  virtualisation.docker.enable = true;

  cachix.github-runner = {
    enable = true;
    count = 4;
    githubOrganization = "cachix";
    namePrefix = "cachix-${pkgs.stdenv.system}";
    extraGroups = [ "docker" ];
    tokenFile = config.age.secrets.github-runner-token.path;
    serviceOverrides = {
      # TODO: merge this properly
      ReadWritePaths = [
        "/nix/var/nix/profiles/per-user/"
        (toString config.age.secrets.nix-access-tokens.path)
      ];
    };
  };

  system.stateVersion = "23.11";
}
